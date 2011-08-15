require 'cul_image_props/image/magic'
require 'cul_image_props/image/properties/exif/types'
require 'cul_image_props/image/properties/exif/constants'
module Cul
module Image
module Properties
module Exif


# process an image file (expects an open file object)
# this is the function that has to deal with all the arbitrary nasty bits
# of the EXIF standard
def self.process_file(f, opts={})
    def_opts = { :stop_tag => 'UNDEF', :details => true, :strict => false }
    opts = def_opts.merge(opts)
    stop_tag = opts[:stop_tag]
    details = opts[:details]
    strict = opts[:strict]

    # by default do not fake an EXIF beginning
    fake_exif = 0

    # determine whether it's a JPEG or TIFF
    data = f.read(12)
    jfif = {}
    if [Cul::Image::Magic::TIFF_MOTOROLA_BE, Cul::Image::Magic::TIFF_INTEL_LE].include? data[0, 4]
        # it's a TIFF file
        f.seek(0)
        endian = data[0,1]
        offset = 0
    elsif data[0,2] == "\xFF\xD8"
        # it's a JPEG file
        base = 0
        while data[2] == "\xFF" and ['JFIF', 'JFXX', 'OLYM', 'Phot'].include? data[6, 4]
            length = ord(data[4])*256+data[5]
            f.read(length-8)
            # fake an EXIF beginning of file
            data = "\xFF\x00"+f.read(10)
            fake_exif = 1
            base = base + length
        end
        # Big ugly patch to deal with APP2 (or other) data coming before APP1
        f.seek(0)
        data = f.read(base+8000) # in theory, this could be insufficient --gd

        base = 2
        fptr = base
        while true
            if data[fptr,2]=="\xFF\xE1"
                puts " APP1 "
                if data[fptr+4,4] == "Exif"
                    base = fptr-2
                    break
                end
                fptr=fptr+ord(data[fptr+2])*256+ord(data[fptr+3])+2
            elsif data[fptr,2]=="\xFF\xE2"
                # APP2
                fptr=fptr+ord(data[fptr+2])*256+ord(data[fptr+3])+2
            elsif data[fptr,2]=="\xFF\xE0"
                # APP0
                offset = fptr
                fptr += 2
                fptr += data[fptr,2].unpack('n')[0]
                #fptr=fptr+(data[fptr+2]*256)+ord(data[fptr+3])+2

                exif = EXIF_TAGS[0x0128]
                label = 'Image ' + exif.name
                if (data[offset+11] == "\x00")
                    jfif[label] = IFD_Tag.new(exif.value[1],label,3,[0],offset+11,1)
                elsif (data[offset+11] == "\x01")
                    jfif[label] = IFD_Tag.new(exif.value[2],label,3,[0],offset+11,1)
                elsif (data[offset+11] == "\x02")
                    jfif[label] = IFD_Tag.new(exif.value[3],label,3,[0],offset+11,1)
                else
                    jfif[label] = IFD_Tag.new("Unknown",label,3,[0],offset+11,1)
                end
                xres = data[offset+12,2].unpack('n')[0]
                yres = data[offset+14,2].unpack('n')[0]
                exif = EXIF_TAGS[0x011a]
                label = 'Image ' + EXIF_TAGS[0x011a].name
                jfif[label] = IFD_Tag.new(xres.to_s,label,5,[xres],offset+12,2)
                label = 'Image ' + EXIF_TAGS[0x011b].name
                jfif[label] = IFD_Tag.new(yres.to_s,label,5,[yres],offset+13,2)
            else
                if(data.length < fptr + 2)
                    break
                end
                _next = data.index("\xff",fptr + 2)
                _next = nil if !_next.nil? and _next + 2 >= data.length
                while (!_next.nil? and data[_next + 1] == 0x00)
                    _next = data.index("\xff",_next + 2)
                    _next = nil if !_next.nil? and _next + 2 >= data.length
                end
                unless (_next.nil?)
                   fptr = _next
                else
                   break
                end
            end
        end
        f.seek(base+12)
        if data[2+base] == 0xFF and data[6+base =>10+base] == 'Exif'
            # detected EXIF header
            offset = f.tell()
            endian = f.read(1)
        else
            # no EXIF information
            unless fake_exif
                return {}
            else
                return jfif
            end
        end
    else
        # file format not recognized
        return {}
    end
    # deal with the EXIF info we found

    hdr = EXIF_header.new(f, endian, offset, fake_exif, strict)
    jfif.each { |tag|
        unless hdr.tags.include? tag
            hdr.tags[tag] = jfif[tag]
        end
    }
    ifd_list = hdr.list_IFDs()
    ctr = 0
    ifd_list.each { |i|
        if ctr == 0
            ifd_name = 'Image'
        elsif ctr == 1
            ifd_name = 'Thumbnail'
            thumb_ifd = i
        else
            ifd_name = 'IFD %d' % ctr
        end
        hdr.dump_IFD(i, ifd_name, {:dict=>EXIF_TAGS, :relative=>false, :stop_tag=>stop_tag})
        # EXIF IFD
        exif_off = hdr.tags[ifd_name +' ExifOffset']
        if exif_off
            hdr.dump_IFD(exif_off.values[0], 'EXIF', {:dict=>EXIF_TAGS, :relative=>false, :stop_tag =>stop_tag})
            # Interoperability IFD contained in EXIF IFD
            intr_off = hdr.tags['EXIF SubIFD InteroperabilityOffset']
            if intr_off
                hdr.dump_IFD(intr_off.values[0], 'EXIF Interoperability',
                             :dict=>INTR_TAGS, :relative=>false, :stop_tag =>stop_tag)
            end
        end
        # GPS IFD
        gps_off = hdr.tags[ifd_name+' GPSInfo']
        if gps_off
            hdr.dump_IFD(gps_off.values[0], 'GPS', {:dict=>GPS_TAGS, :relative=>false, :stop_tag =>stop_tag})
        end
        ctr += 1
    }
    # extract uncompressed TIFF thumbnail
    thumb = hdr.tags['Thumbnail Compression']
    if thumb and thumb.printable == 'Uncompressed TIFF'
        hdr.extract_TIFF_thumbnail(thumb_ifd)
    end
    # JPEG thumbnail (thankfully the JPEG data is stored as a unit)
    thumb_off = hdr.tags['Thumbnail JPEGInterchangeFormat']
    if thumb_off
        f.seek(offset+thumb_off.values[0])
        size = hdr.tags['Thumbnail JPEGInterchangeFormatLength'].values[0]
        hdr.tags['JPEGThumbnail'] = f.read(size)
    end

    # deal with MakerNote contained in EXIF IFD
    # (Some apps use MakerNote tags but do not use a format for which we
    # have a description, do not process these).
    if hdr.tags.include? 'EXIF MakerNote' and hdr.tags.include? 'Image Make' and detailed
        hdr.decode_maker_note()
    end

    # Sometimes in a TIFF file, a JPEG thumbnail is hidden in the MakerNote
    # since it's not allowed in a uncompressed TIFF IFD
    unless hdr.tags.include? 'JPEGThumbnail'
        thumb_off=hdr.tags['MakerNote JPEGThumbnail']
        if thumb_off
            f.seek(offset+thumb_off.values[0])
            hdr.tags['JPEGThumbnail']=file.read(thumb_off.field_length)
        end
    end
    return hdr.tags
end

end
end
end
end