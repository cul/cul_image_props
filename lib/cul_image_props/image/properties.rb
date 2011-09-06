require 'cul_image_props/image/properties/version'
require 'cul_image_props/image/properties/types'
require 'cul_image_props/image/magic'
require 'open-uri'

module Cul
module Image
module Properties
  def self.identify(src)
    if src.is_a? String
      src = open(src)
    end
    filesize = src.stat.size
    result = nil
    magic_bytes = ''
    buf = ''
    src.read(2,buf)
    magic_bytes << buf
    case magic_bytes
    when Cul::Image::Magic::BMP
      result = Cul::Image::Properties::Bmp.new(src)
    when Cul::Image::Magic::JPEG
      result = Cul::Image::Properties::Jpeg.new(src)
    end

    if result.nil?
      src.read(2,buf)
      magic_bytes << buf
      case magic_bytes
      when Cul::Image::Magic::TIFF_MOTOROLA_BE
        result = Cul::Image::Properties::Tiff.new(src)
      when Cul::Image::Magic::TIFF_INTEL_LE
        result = Cul::Image::Properties::Tiff.new(src)
      when Cul::Image::Magic::GIF
        result = Cul::Image::Properties::Gif.new(src)
      end
    end
    if result.nil?
      src.read(4,buf)
      magic_bytes << buf
      if magic_bytes == Cul::Image::Magic::PNG
        result = Cul::Image::Properties::Png.new(src)
      else
        puts magic_bytes.unpack('H2H2H2H2H2H2H2H2').inspect
      end
    end
    return result
  end
end
end
end
