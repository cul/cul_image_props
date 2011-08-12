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
    elsif data[0,2] == '\xFF\xD8'
        # it's a JPEG file
        base = 0
        while data[2] == '\xFF' and ['JFIF', 'JFXX', 'OLYM', 'Phot'].include? data[6, 4]
            length = ord(data[4])*256+data[5]
            f.read(length-8)
            # fake an EXIF beginning of file
            data = '\xFF\x00'+f.read(10)
            fake_exif = 1
            base = base + length
        end
        # Big ugly patch to deal with APP2 (or other) data coming before APP1
        f.seek(0)
        data = f.read(base+8000) # in theory, this could be insufficient --gd

        base = 2
        fptr = base
        while true
            if data[fptr,2]=='\xFF\xE1'
                # APP1
                if data[fptr+4,4] == "Exif"
                    base = fptr-2
                    break
                end
                fptr=fptr+ord(data[fptr+2])*256+ord(data[fptr+3])+2
            elsif data[fptr,2]=='\xFF\xE2'
                # APP2
                fptr=fptr+ord(data[fptr+2])*256+ord(data[fptr+3])+2
            elsif data[fptr,2]=='\xFF\xE0'
                # APP0
                offset = fptr
                fptr=fptr+ord(data[fptr+2])*256+ord(data[fptr+3])+2

                exif = EXIF_TAGS.get(0x0128)
                label = 'Image ' + exif[0]
                if (data[offset+11] == '\x00')
                    jfif[label] = IFD_Tag(field_offset=offset+11,field_length=1,printable=exif[1].get(1),tag=label,field_type=3,values=[1])
                elsif (data[offset+11] == '\x01')
                    jfif[label] = IFD_Tag(field_offset=offset+11,field_length=1,printable=exif[1].get(2),tag=label,field_type=3,values=[2])
                elsif (data[offset+11] == '\x02')
                    jfif[label] = IFD_Tag(field_offset=offset+11,field_length=1,printable=exif[1].get(3),tag=label,field_type=3,values=[3])
                else
                    jfif[label] = IFD_Tag(field_offset=offset+11,field_length=1,printable="Unknown",tag=label,field_type=3,values=[0])
                end
                xres = ord(data[offset+12])*256+ord(data[offset+13])
                yres = ord(data[offset+14])*256+ord(data[offset+15])
                exif = EXIF_TAGS.get(0x011a)
                label = 'Image ' + EXIF_TAGS.get(0x011a)[0]
                jfif[label] = IFD_Tag(field_offset=offset+12,field_length=2,printable=xres.to_s,tag=label,field_type=5,values=[xres])
                label = 'Image ' + EXIF_TAGS.get(0x011b)[0]
                jfif[label] = IFD_Tag(field_offset=offset+13,field_length=2,printable=yres.to_s,tag=label,field_type=5,values=[yres])
            else
                if(len(data) < fptr + 2)
                    break
                end
                _next = data.find('\xff',fptr + 2,-2)
                while (_next != -1 and data[_next + 1] == 0x00)
                    _next = data.find('\xff',_next + 2,-2)
                end
                if (_next != -1)
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
        hdr.dump_IFD(i, ifd_name, EXIF_TAGS, 0, stop_tag)
        # EXIF IFD
        exif_off = hdr.tags[ifd_name +' ExifOffset']
        if exif_off
            hdr.dump_IFD(exif_off.values[0], 'EXIF', EXIF_TAGS, 0, stop_tag)
            # Interoperability IFD contained in EXIF IFD
            intr_off = hdr.tags['EXIF SubIFD InteroperabilityOffset']
            if intr_off
                hdr.dump_IFD(intr_off.values[0], 'EXIF Interoperability',
                             INTR_TAGS, 0, stop_tag)
            end
        end
        # GPS IFD
        gps_off = hdr.tags[ifd_name+' GPSInfo']
        if gps_off
            hdr.dump_IFD(gps_off.values[0], 'GPS', GPS_TAGS, 0, stop_tag)
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