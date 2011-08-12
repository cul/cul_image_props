require 'nokogiri'
require 'cul_image_props/image/properties/exif'
module Cul
module Image
module Properties

class Namespace
  def initialize(href, prefix)
    @href = href
    @prefix = prefix
  end
  def href
    @href
  end
  def prefix
    @prefix
  end
end

ASSESS = Namespace.new("http://purl.oclc.org/NET/CUL/RESOURCE/STILLIMAGE/ASSESSMENT/","si-assess")
BASIC = Namespace.new("http://purl.oclc.org/NET/CUL/RESOURCE/STILLIMAGE/BASIC/","si-basic")
DCMI = Namespace.new("http://purl.org/dc/terms/","dcmi")

class Base
  attr_accessor :nodeset
  BASE_XML = Nokogiri::XML.parse(<<-xml
<rdf:Description xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
 xmlns:si-assess="http://purl.oclc.org/NET/CUL/RESOURCE/STILLIMAGE/ASSESSMENT/"
 xmlns:si-basic="http://purl.oclc.org/NET/CUL/RESOURCE/STILLIMAGE/BASIC/"
 xmlns:dcmi="http://purl.org/dc/terms/"></rdf:Description>
xml
)
  def initialize(srcfile=nil)
    @src = srcfile
    @src.rewind
    @ng_xml = BASE_XML.clone
  end
  def nodeset
    @ng_xml.root.element_children
  end
  def [](key)
    result = nil
    nodeset.each { |node|
      if (node.namespace.href + node.name) == key
        if node.attribute('resource').nil?
          result = node.text
        else
          result = node.attribute('resource').value
        end
      end
    }
    result
  end
  def add_dt_prop(prefix, name, value)
    prop = @ng_xml.create_element(name)
    @ng_xml.root.namespace_definitions.each { |ns| prop.namespace = ns if ns.prefix == prefix }
    prop.add_child(@ng_xml.create_text_node(value.to_s))
    @ng_xml.root.add_child( prop )
  end

  def sampling_unit=(name)
    prop = @ng_xml.create_element("samplingFrequencyUnit")
    @ng_xml.root.namespace_definitions.each { |ns| prop.namespace = ns if ns.prefix == "si-assess" }
    @ng_xml.root.add_child( prop )
    prop.set_attribute("rdf:resource", prop.namespace.href + name)
  end

  def x_sampling_freq=(value)
    add_dt_prop("si-assess", "xSamplingFrequency", value)
  end

  def y_sampling_freq=(value)
    add_dt_prop("si-assess", "ySamplingFrequency", value)
  end

  def width=(value)
    add_dt_prop("si-basic", "imageWidth", value)
  end

  def length=(value)
    add_dt_prop("si-basic", "imageLength", value)
  end

  def extent=(value)
    add_dt_prop("dcmi", "extent", value)
  end
end

class Bmp < Base
  def initialize(srcfile=nil)
    super
    header_bytes = @src.read(18)
    raise "Source file is not a bitmap" unless header_bytes[0...2] == Cul::Image::Magic::BMP
    size = header_bytes[-4,4].unpack('V')[0]
    header_bytes = header_bytes + @src.read(size)
    dims = header_bytes[0x12...0x1a].unpack('VV')
    sampling = header_bytes[0x26...0x2e].unpack('VV')
    self.sampling_unit='CentimeterSampling'
    self.width= dims[0]
    self.length= dims[1]
    self.extent= srcfile.stat.size unless srcfile.nil?
    self.x_sampling_freq= (sampling[0]) # / 100).ceil
    self.y_sampling_freq= (sampling[1]) # / 100).ceil
    @src.close
  end
end

class Gif < Base
  def initialize(srcfile=nil)
    super
    header_bytes = @src.read(13)
    raise "Source file is not a gif" unless header_bytes[0...4] == Cul::Image::Magic::GIF
    self.width= header_bytes[6,2].unpack('v')[0]
    self.length= header_bytes[8,2].unpack('v')[0]
    self.extent= srcfile.stat.size unless srcfile.nil?
    @src.close
  end
end

class Jpeg < Base
  def initialize(srcfile=nil)
    super
    header_bytes = @src.read(13)
    raise "Source file is not a jpeg" unless header_bytes[0...2] == Cul::Image::Magic::JPEG
    xpix = 0
    ypix = 0
    while (!srcfile.eof?)
      if "\xFF" == srcfile.read(1)
        mrkr = "\xFF" + srcfile.read(1)
        blen = srcfile.read(2).unpack('n')[0]
        if JPEG_FRAME_MARKERS.include? mrkr  # SOFn, Start of frame for scans
          srcfile.read(1) #skip bits per sample
          self.length= srcfile.read(2).unpack('n')[0]
          self.width= srcfile.read(2).unpack('n')[0]
          srcfile.seek(0, IO::SEEK_END)
        end
      else
        srcfile.seek(0, IO::SEEK_END)
      end
    end

    @src.rewind
    tags = Cul::Image::Properties::Exif.process_file(srcfile)
    if tags.include? 'Image ImageWidth'
      self.width= tags['Image ImageWidth'].values[0]
    end
    if tags.include? 'Image ImageLength'
      self.length= tags['Image ImageLength'].values[0]
    end
    if tags.include? 'Image XResolution'
      self.x_sampling_freq= tags['Image XResolution'].values[0]
    end
    if tags.include? 'Image YResolution'
      self.y_sampling_freq= tags['Image YResolution'].values[0]
    end
    if tags.include? 'Image ResolutionUnit'
      if (tags['Image ResolutionUnit'].values[0] == 3)
        self.sampling_unit='CentimeterSampling'
      elsif (tags['Image ResolutionUnit'].values[0] == 2)
        self.sampling_unit='InchSampling'
      else
        self.sampling_unit='NoAbsoluteSampling'
      end
    end
    self.extent= srcfile.stat.size unless srcfile.nil?
    @src.close
  end
end

class Png < Base
  def initialize(srcfile=nil)
    super
    header_bytes = @src.read(8)
    raise "Source file is not a png" unless header_bytes[0...8] == Cul::Image::Magic::PNG
    until @src.eof?
      clen = @src.read(4).unpack('N')[0]
      ctype = @src.read(4)
      case ctype
      when 'pHYs'
        pHYs(clen)
      when 'IHDR'
        IHDR(clen)
      when 'tEXt'
        tEXt(clen)
      when 'IEND'
        IEND(clen)
      else
        @src.seek(clen+4, IO::SEEK_CUR)
      end
    end
    self.extent= srcfile.stat.size unless srcfile.nil?
    @src.close
  end
  def pHYs(len)
    val = @src.read(9)
    xres = val[0,4].unpack('N')[0]
    yres = val[4,4].unpack('N')[0]
    unit = val[8]
    if unit == 1 # resolution unit is METER
      xres = (xres / 100).ceil
      yres = (yres / 100).ceil
      self.sampling_unit='CentimeterSampling'
    else
      self.sampling_unit='NoAbsoluteSampling'
    end
    self.x_sampling_freq= xres
    self.y_sampling_freq= yres
    @src.seek(len - 5, IO::SEEK_CUR) # remaining block + end tag
  end
  def IHDR(len)
    val = @src.read(8)
    self.width= val[0,4].unpack('N')[0]
    self.length= val[4,4].unpack('N')[0]
    @src.seek(len - 4, IO::SEEK_CUR) # remaining block + end tag
  end
  def tEXt(len)
    @src.seek(len + 4, IO::SEEK_CUR) # remaining block + end tag
  end
  def IEND(len)
    @src.seek(0, IO::SEEK_END)
  end
end

module Exif
  def read_header(srcfile, endian, offset)
    return ExifHeader(srcfile, endian, offset)
  end
end

module LittleEndian
  def byte(str, signed=false)
    if signed
      return str[0,1].unpack('c')[0]
    else
      return str[0,1].unpack('C')[0]
    end
  end
  def short(str, signed=false)
    result = str[0,2].unpack('v')[0]
    if signed
      return ~ result unless result < 32768
    end
    return result
  end
  def int(str, signed=false)
    result = str[0,4].unpack('V')[0]
    if signed
      return ~ result unless result < 2147483648
    end
    return result
  end
end

module BigEndian
  def byte(str, signed=false)
    if signed
      return str[0,1].unpack('c')[0]
    else
      return str[0,1].unpack('C')[0]
    end
  end
  def short(str, signed=false)
    result = str[0,2].unpack('n')[0]
    if signed
      return ~ result unless result < 32768
    end
    return result
  end
  def int(str, signed=false)
    result = str[0,4].unpack('N')[0]
    if signed
      return ~ result unless result < 2147483648
    end
    return result
  end
end

class Tiff < Base
  def initialize(srcfile=nil)
    super
    header_bytes = @src.read(14)
    case header_bytes[0...4]
    when Cul::Image::Magic::TIFF_INTEL_LE
      @endian = header_bytes[12]
    when Cul::Image::Magic::TIFF_MOTOROLA_BE
      @endian = header_bytes[12]
    else
      raise "Source file is not a tiff" 
    end
    @src.rewind
    tags = Cul::Image::Properties::Exif.process_file(srcfile)
    if tags.include? 'Image ImageWidth'
      self.width= tags['Image ImageWidth'].values[0]
    end
    if tags.include? 'Image ImageLength'
      self.length= tags['Image ImageLength'].values[0]
    end
    if tags.include? 'Image XResolution'
      self.x_sampling_freq= tags['Image XResolution'].values[0].inspect
    end
    if tags.include? 'Image YResolution'
      self.y_sampling_freq= tags['Image YResolution'].values[0].inspect
    end
    if tags.include? 'Image ResolutionUnit'
      if (tags['Image ResolutionUnit'].values[0] == 3)
        self.sampling_unit='CentimeterSampling'
      elsif (tags['Image ResolutionUnit'].values[0] == 2)
        self.sampling_unit='InchSampling'
      else
        self.sampling_unit='NoAbsoluteSampling'
      end
    end
    # do stuff with tags
    self.extent= srcfile.stat.size unless srcfile.nil?
    @src.close
  end
end

end
end
end