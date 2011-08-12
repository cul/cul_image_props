module Cul
module Image
module Properties
module Exif

class FieldType
  attr_accessor :length, :abbreviation, :name
  def initialize(length, abb, name)
    @length = length
    @abbreviation = abb
    @name = name
  end
  def [](index)
    case index
      when 0
        return @length
      when 1
        return @abbreviation
      when 2
        return @name
      else
        raise format("Unexpected index %s", index.to_s)
    end
  end
end

# first element of tuple is tag name, optional second element is
# another dictionary giving names to values
class TagName
  attr_accessor :name, :value
  def initialize(name, value=false)
    @name = name
    @value = value
  end
end

class Ratio
    # ratio object that eventually will be able to reduce itself to lowest
    # common denominator for printing
    attr_accessor :num, :den
    def gcd(a, b)
        if b == 1 or a == 1
            return 1
        elsif b == 0
            return a
        else
            return gcd(b, a % b)
        end
    end

    def initialize(num, den)
        @num = num
        @den = den
    end

    def inspect
        self.reduce()
        if @den == 1
            return str(self.num)
        end
        return format("%d/%d", @num, @den)
    end

    def reduce
        div = gcd(@num, @den)
        if div > 1
            @num = @num / div
            @den = @den / div
        end
    end
end

# for ease of dealing with tags
class IFD_Tag
    attr_accessor :printable, :tag, :field_type, :values, :field_offset, :field_length
    def initialize( printable, tag, field_type, values, field_offset,
                 field_length)
        # printable version of data
        @printable = printable
        # tag ID number
        @tag = tag
        # field type as index into FIELD_TYPES
        @field_type = field_type
        # offset of start of field in bytes from beginning of IFD
        @field_offset = field_offset
        # length of data field in bytes
        @field_length = field_length
        # either a string or array of data items
        @values = values
    end

    def to_s
        return @printable
    end

    def inspect
        begin
            s= format("(0x%04X) %s=%s @ %d", @tag,
                                        FIELD_TYPES[@field_type][2],
                                        @printable,
                                        @field_offset)
        rescue
            s= format("(%s) %s=%s @ %s", @tag.to_s,
                                        FIELD_TYPES[@field_type][2],
                                        @printable,
                                        @field_offset.to_s)
        end
        return s
    end
end

# class that handles an EXIF header
class EXIF_header
    attr_accessor :tags
    def initialize(file, endian, offset, fake_exif, strict, detail=true)
        @file = file
        @endian = endian
        @offset = offset
        @fake_exif = fake_exif
        @strict = strict
        @detail = detail
        @tags = {}
    end

# extract multibyte integer in Motorola format (little endian)
    def s2n_motorola(str)
        x = 0
        str.each_byte { |c|
            x = (x << 8) | c
        }
        return x
    end
# extract multibyte integer in Intel format (big endian)
    def s2n_intel(str)
        x = 0
        y = 0
        str.each_byte { |c|
            x = x | (c << y)
            y = y + 8
        }
        return x
      end

    # convert slice to integer, based on sign and endian flags
    # usually this offset is assumed to be relative to the beginning of the
    # start of the EXIF information.  For some cameras that use relative tags,
    # this offset may be relative to some other starting point.
    def s2n(offset, length, signed=false)
        @file.seek(@offset+offset)
        slice=@file.read(length)
        if @endian == 'I'
            val=s2n_intel(slice)
        else
            val=s2n_motorola(slice)
        end
        # Sign extension ?
        if signed
            msb= 1 << (8*length-1)
            if val & msb
                val=val-(msb << 1)
            end
        end
        return val
    end

    # convert offset to string
    def n2s(offset, length)
        s = ''
        length.times {
            if @endian == 'I'
                s = s + chr(offset & 0xFF)
            else
                s = chr(offset & 0xFF) + s
            end
            offset = offset >> 8
        }
        return s
    end

    # return first IFD
    def first_IFD()
        return s2n(4, 4)
    end

    # return pointer to next IFD
    def next_IFD(ifd)
        entries=self.s2n(ifd, 2)
        return self.s2n(ifd+2+12*entries, 4)
    end

    # return list of IFDs in header
    def list_IFDs()
        i=self.first_IFD()
        a=[]
        while i != 0
            a << i
            i=self.next_IFD(i)
        end
        return a
    end

    # return list of entries in this IFD
    def dump_IFD(ifd, ifd_name, dict=EXIF_TAGS, relative=0, stop_tag='UNDEF')
        entries=self.s2n(ifd, 2)
        puts ifd_name + " had zero entries!" if entries == 0
        (0 ... entries).each { |i|
            # entry is index of start of this IFD in the file
            entry = ifd + 2 + 12 * i
            tag = self.s2n(entry, 2)

            # get tag name early to avoid errors, help debug
            tag_entry = dict[tag]
            if tag_entry
                tag_name = tag_entry.name
            else
                tag_name = 'Tag 0x%04X' % tag
            end

            # ignore certain tags for faster processing
            if not (not @detail and IGNORE_TAGS.include? tag)
                field_type = self.s2n(entry + 2, 2)
                
                # unknown field type
                if 0 > field_type or field_type > FIELD_TYPES.length
                    if not self.strict
                        next
                    else
                        raise format("unknown type %d in tag 0x%04X", field_type, tag)
                    end
                end
                typelen = FIELD_TYPES[field_type][0]
                count = self.s2n(entry + 4, 4)
                # Adjust for tag id/type/count (2+2+4 bytes)
                # Now we point at either the data or the 2nd level offset
                offset = entry + 8

                # If the value fits in 4 bytes, it is inlined, else we
                # need to jump ahead again.
                if count * typelen > 4
                    # offset is not the value; it's a pointer to the value
                    # if relative we set things up so s2n will seek to the right
                    # place when it adds self.offset.  Note that this 'relative'
                    # is for the Nikon type 3 makernote.  Other cameras may use
                    # other relative offsets, which would have to be computed here
                    # slightly differently.
                    if relative
                        tmp_offset = self.s2n(offset, 4)
                        offset = tmp_offset + ifd - 8
                        if @fake_exif
                            offset = offset + 18
                        end
                    else
                        offset = self.s2n(offset, 4)
                    end
                end

                field_offset = offset
                if field_type == 2
                    # special case => null-terminated ASCII string
                    # XXX investigate
                    # sometimes gets too big to fit in int value
                    if count != 0 and count < (2**31)
                        @file.seek(self.offset + offset)
                        values = @file.read(count)
                        #print values
                        # Drop any garbage after a null.
                        values = values.split('\x00', 1)[0]
                    else
                        values = ''
                    end
                else
                    values = []
                    signed = [6, 8, 9, 10].include? field_type
                    
                    # XXX investigate
                    # some entries get too big to handle could be malformed
                    # file or problem with self.s2n
                    if count < 1000
                        count.times {
                            if field_type == 5 or field_type == 10
                                # a ratio
                                value = Ratio.new(self.s2n(offset, 4, signed),
                                              self.s2n(offset + 4, 4, signed))
                            else
                                value = self.s2n(offset, typelen, signed)
                            end
                            values << value
                            offset = offset + typelen
                        }
                    # The test above causes problems with tags that are 
                    # supposed to have long values!  Fix up one important case.
                    elsif tag_name == 'MakerNote'
                        count.times {
                            value = self.s2n(offset, typelen, signed)
                            values << value
                            offset = offset + typelen
                        }
                    end
                end
                # now 'values' is either a string or an array
                if count == 1 and field_type != 2
                    printable=values[0].to_s
                elsif count > 50 and values.length > 20
                    printable=str( values[0 =>20] )[0 =>-1] + ", ... ]"
                else
                    printable=values.inspect
                end
                # compute printable version of values
                if tag_entry
                    if tag_entry.value
                        # optional 2nd tag element is present
                        if tag_entry.value.respond_to? :call
                            # call mapping function
                            printable = tag_entry.value.call(values)
                        else
                            printable = ''
                            values.each { |i|
                                # use lookup table for this tag
                                printable += (tag_entry.value.include? i)?tag_entry.value[i] : i.inspect
                            }
                        end
                     end
                end
                puts ifd_name + ' ' + tag_name + " == " + values.inspect
                self.tags[ifd_name + ' ' + tag_name] = IFD_Tag.new(printable, tag,
                                                          field_type,
                                                          values, field_offset,
                                                          count * typelen)
            end
            if tag_name == stop_tag
                break
            end
        }
    end

    # extract uncompressed TIFF thumbnail (like pulling teeth)
    # we take advantage of the pre-existing layout in the thumbnail IFD as
    # much as possible
    def extract_TIFF_thumbnail(thumb_ifd)
        entries = self.s2n(thumb_ifd, 2)
        # this is header plus offset to IFD ...
        if @endian == 'M'
            tiff = 'MM\x00*\x00\x00\x00\x08'
        else
            tiff = 'II*\x00\x08\x00\x00\x00'
        end
        # ... plus thumbnail IFD data plus a null "next IFD" pointer
        self.file.seek(self.offset+thumb_ifd)
        tiff += self.file.read(entries*12+2)+'\x00\x00\x00\x00'

        # fix up large value offset pointers into data area
        (0...entries).each { |i|
            entry = thumb_ifd + 2 + 12 * i
            tag = self.s2n(entry, 2)
            field_type = self.s2n(entry+2, 2)
            typelen = FIELD_TYPES[field_type][0]
            count = self.s2n(entry+4, 4)
            oldoff = self.s2n(entry+8, 4)
            # start of the 4-byte pointer area in entry
            ptr = i * 12 + 18
            # remember strip offsets location
            if tag == 0x0111
                strip_off = ptr
                strip_len = count * typelen
            end
            # is it in the data area?
            if count * typelen > 4
                # update offset pointer (nasty "strings are immutable" crap)
                # should be able to say "tiff[ptr..ptr+4]=newoff"
                newoff = len(tiff)
                tiff = tiff[ 0..ptr] + self.n2s(newoff, 4) + tiff[ptr+4...tiff.length]
                # remember strip offsets location
                if tag == 0x0111
                    strip_off = newoff
                    strip_len = 4
                end
                # get original data and store it
                self.file.seek(self.offset + oldoff)
                tiff += self.file.read(count * typelen)
            end
        }
        # add pixel strips and update strip offset info
        old_offsets = self.tags['Thumbnail StripOffsets'].values
        old_counts = self.tags['Thumbnail StripByteCounts'].values
        (0...len(old_offsets)).each { |i|
            # update offset pointer (more nasty "strings are immutable" crap)
            offset = self.n2s(len(tiff), strip_len)
            tiff = tiff[ 0..strip_off] + offset + tiff[strip_off + strip_len ... tiff.length]
            strip_off += strip_len
            # add pixel strip to end
            self.file.seek(self.offset + old_offsets[i])
            tiff += self.file.read(old_counts[i])
        }
        self.tags['TIFFThumbnail'] = tiff
    end

    # decode all the camera-specific MakerNote formats

    # Note is the data that comprises this MakerNote.  The MakerNote will
    # likely have pointers in it that point to other parts of the file.  We'll
    # use self.offset as the starting point for most of those pointers, since
    # they are relative to the beginning of the file.
    #
    # If the MakerNote is in a newer format, it may use relative addressing
    # within the MakerNote.  In that case we'll use relative addresses for the
    # pointers.
    #
    # As an aside => it's not just to be annoying that the manufacturers use
    # relative offsets.  It's so that if the makernote has to be moved by the
    # picture software all of the offsets don't have to be adjusted.  Overall,
    # this is probably the right strategy for makernotes, though the spec is
    # ambiguous.  (The spec does not appear to imagine that makernotes would
    # follow EXIF format internally.  Once they did, it's ambiguous whether
    # the offsets should be from the header at the start of all the EXIF info,
    # or from the header at the start of the makernote.)
    def decode_maker_note()
        note = self.tags['EXIF MakerNote']
        
        # Some apps use MakerNote tags but do not use a format for which we
        # have a description, so just do a raw dump for these.

        make = self.tags['Image Make'].printable

        # Nikon
        # The maker note usually starts with the word Nikon, followed by the
        # type of the makernote (1 or 2, as a short).  If the word Nikon is
        # not at the start of the makernote, it's probably type 2, since some
        # cameras work that way.
        if make.include? 'NIKON'
            if note.values[0,7] == [78, 105, 107, 111, 110, 0, 1]
                self.dump_IFD(note.field_offset+8, 'MakerNote',
                              MAKERNOTE_NIKON_OLDER_TAGS)
            elsif note.values[0, 7] == [78, 105, 107, 111, 110, 0, 2]
                if note.values[12,2] != [0, 42] and note.values[12,2] != [42, 0]
                    raise "Missing marker tag '42' in MakerNote."
                end
                # skip the Makernote label and the TIFF header
                self.dump_IFD(note.field_offset+10+8, 'MakerNote',
                              MAKERNOTE_NIKON_NEWER_TAGS, :relative=>1)
            else
                # E99x or D1
                self.dump_IFD(note.field_offset, 'MakerNote',
                              MAKERNOTE_NIKON_NEWER_TAGS)
            end
            return
        end
        # Olympus
        if make.index('OLYMPUS') == 0
            self.dump_IFD(note.field_offset+8, 'MakerNote',
                          MAKERNOTE_OLYMPUS_TAGS)
            return
        end
        # Casio
        if make.include? 'CASIO' or make.include? 'Casio'
            self.dump_IFD(note.field_offset, 'MakerNote',
                          MAKERNOTE_CASIO_TAGS)
            return
        end
        # Fujifilm
        if make == 'FUJIFILM'
            # bug => everything else is "Motorola" endian, but the MakerNote
            # is "Intel" endian
            endian = self.endian
            self.endian = 'I'
            # bug => IFD offsets are from beginning of MakerNote, not
            # beginning of file header
            offset = self.offset
            self.offset += note.field_offset
            # process note with bogus values (note is actually at offset 12)
            self.dump_IFD(12, 'MakerNote', MAKERNOTE_FUJIFILM_TAGS)
            # reset to correct values
            self.endian = endian
            self.offset = offset
            return
        end
        # Canon
        if make == 'Canon'
            self.dump_IFD(note.field_offset, 'MakerNote',
                          MAKERNOTE_CANON_TAGS)
            [['MakerNote Tag 0x0001', MAKERNOTE_CANON_TAG_0x001],
                      ['MakerNote Tag 0x0004', MAKERNOTE_CANON_TAG_0x004]].each { |i|
                begin
                  self.canon_decode_tag(self.tags[i[0]].values, i[1])  # gd added 
                rescue
                end
            }
            return
        end
    end

    # XXX TODO decode Olympus MakerNote tag based on offset within tag
    def olympus_decode_tag(value, dict)
    end

    # decode Canon MakerNote tag based on offset within tag
    # see http =>//www.burren.cx/david/canon.html by David Burren
    def canon_decode_tag(value, dict)
        (1 ... len(value)).each { |i|
            x=dict.get(i, ['Unknown'])

            name=x[0]
            if len(x) > 1
                val=x[1].get(value[i], 'Unknown')
            else
                val=value[i]
            end
            # it's not a real IFD Tag but we fake one to make everybody
            # happy. this will have a "proprietary" type
            self.tags['MakerNote '+name]=IFD_Tag(str(val), None, 0, None,
                                                 None, None)
        }
    end
end # EXIF_header

end # ::Exif
end # ::Properties
end # ::Image
end # ::Cul
