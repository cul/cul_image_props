require 'cul_image_props/image/properties/exif/types'
module Cul
module Image
module Properties
module Exif

# Don't throw an exception when given an out of range character.
def self.ascii_bytes_to_filtered_string(seq)
  if seq.is_a? String
    seq = seq.unpack('C*')
  end
  str = ''
  seq.each { |c|
    # Screen out non-printing characters
    unless c.is_a? Fixnum
      raise "Expected an array of ASCII8BIT bytes, got an array value #{c.class}: #{field_type.inspect}"
    end
    if 32 <= c and c < 256
      str += c.chr
    end
  }
  return str
end
# Special version to deal with the code in the first 8 bytes of a user comment.
# First 8 bytes gives coding system e.g. ASCII vs. JIS vs Unicode
def self.filter_encoded_string(seq)
    if seq.is_a? String
      bytes = seq.unpack('C*')
    else # array of bytes
      bytes = seq
    end
    code = bytes[0, 8]
    seq = bytes[8 ... bytes.length].pack('C*')
    if code == TAG_ENCODING[:ASCII]
      return ascii_bytes_to_filtered_string(bytes[8 ... bytes.length])
    end
    if code == TAG_ENCODING[:UNICODE]
      seq = seq.force_encoding('utf-8') # I see some docs indicating UCS-2 here?
      return seq.gsub(/\p{Cntrl}/,'').gsub(/\P{ASCII}/,'')
    end
    if code == TAG_ENCODING[:JIS]
      # to be implemented
      return "JIS String Value"
    end
    # Fall back to ASCII
    return ascii_bytes_to_filtered_string(bytes[8 ... bytes.length])
end

# decode Olympus SpecialMode tag in MakerNote
def self.olympus_special_mode(v)
    a=[
        'Normal',
        'Unknown',
        'Fast',
        'Panorama']
    b=[
        'Non-panoramic',
        'Left to right',
        'Right to left',
        'Bottom to top',
        'Top to bottom']
    if v[0] >= a.length or v[2] >= b.length
        return v
    end
    return format("%s - sequence %d - %s", a[v[0]], v[1], b[v[2]])
end

# http =>//tomtia.plala.jp/DigitalCamera/MakerNote/index.asp
def self.nikon_ev_bias(seq)
    # First digit seems to be in steps of 1/6 EV.
    # Does the third value mean the step size?  It is usually 6,
    # but it is 12 for the ExposureDifference.
    #
    # Check for an error condition that could cause a crash.
    # This only happens if something has gone really wrong in
    # reading the Nikon MakerNote.
    return "" if len( seq ) < 4 
    #
    case seq
    when [252, 1, 6, 0]
        return "-2/3 EV"
    when [253, 1, 6, 0]
        return "-1/2 EV"
    when [254, 1, 6, 0]
        return "-1/3 EV"
    when [0, 1, 6, 0]
        return "0 EV"
    when [2, 1, 6, 0]
        return "+1/3 EV"
    when [3, 1, 6, 0]
        return "+1/2 EV"
    when [4, 1, 6, 0]
        return "+2/3 EV"
    end
    # Handle combinations not in the table.
    a = seq[0]
    # Causes headaches for the +/- logic, so special case it.
    if a == 0
        return "0 EV"
    elsif a > 127
        a = 256 - a
        ret_str = "-"
    else
        ret_str = "+"
    end
    b = seq[2]	# Assume third value means the step size
    whole = a / b
    a = a % b
    if whole != 0
        ret_str = ret_str + str(whole) + " "
    end
    if a == 0
        ret_str = ret_str + "EV"
    else
        r = Ratio(a, b)
        ret_str = ret_str + r.__repr__() + " EV"
    end
    return ret_str
  end

TAG_ENCODING =  {
  :ASCII =>     [0x41, 0x53, 0x43, 0x49, 0x49, 0x00, 0x00, 0x00],
  :JIS =>       [0x4A, 0x49, 0x53, 0x00, 0x00, 0x00, 0x00, 0x00],
  :UNICODE =>   [0x55, 0x4E, 0x49, 0x43, 0x4F, 0x44, 0x45, 0x00],
  :UNDEFINED => [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
}

# field type descriptions as (length, abbreviation, full name) tuples
FIELD_TYPES = [
    FieldType.new(0, 'X', 'Proprietary'), # no such type
    FieldType.new(1, 'B', 'Byte'),
    FieldType.new(1, 'A', 'ASCII'),
    FieldType.new(2, 'S', 'Short'),
    FieldType.new(4, 'L', 'Long'),
    FieldType.new(8, 'R', 'Ratio'),
    FieldType.new(1, 'SB', 'Signed Byte'),
    FieldType.new(1, 'U', 'Undefined'),
    FieldType.new(2, 'SS', 'Signed Short'),
    FieldType.new(4, 'SL', 'Signed Long'),
    FieldType.new(8, 'SR', 'Signed Ratio')
    ]

# dictionary of main EXIF tag names
EXIF_TAGS = {
    0x0100 => TagName.new('ImageWidth'),
    0x0101 => TagName.new('ImageLength'),
    0x0102 => TagName.new('BitsPerSample'),
    0x0103 => TagName.new('Compression',
             {1 => 'Uncompressed',
              2 => 'CCITT 1D',
              3 => 'T4/Group 3 Fax',
              4 => 'T6/Group 4 Fax',
              5 => 'LZW',
              6 => 'JPEG (old-style)',
              7 => 'JPEG',
              8 => 'Adobe Deflate',
              9 => 'JBIG B&W',
              10 => 'JBIG Color',
              32766 => 'Next',
              32769 => 'Epson ERF Compressed',
              32771 => 'CCIRLEW',
              32773 => 'PackBits',
              32809 => 'Thunderscan',
              32895 => 'IT8CTPAD',
              32896 => 'IT8LW',
              32897 => 'IT8MP',
              32898 => 'IT8BL',
              32908 => 'PixarFilm',
              32909 => 'PixarLog',
              32946 => 'Deflate',
              32947 => 'DCS',
              34661 => 'JBIG',
              34676 => 'SGILog',
              34677 => 'SGILog24',
              34712 => 'JPEG 2000',
              34713 => 'Nikon NEF Compressed',
              65000 => 'Kodak DCR Compressed',
              65535 => 'Pentax PEF Compressed'}),
    0x0106 => TagName.new('PhotometricInterpretation'),
    0x0107 => TagName.new('Thresholding'),
    0x010A => TagName.new('FillOrder'),
    0x010D => TagName.new('DocumentName'),
    0x010E => TagName.new('ImageDescription'),
    0x010F => TagName.new('Make'),
    0x0110 => TagName.new('Model'),
    0x0111 => TagName.new('StripOffsets'),
    0x0112 => TagName.new('Orientation',
             {1 => 'Horizontal (normal)',
              2 => 'Mirrored horizontal',
              3 => 'Rotated 180',
              4 => 'Mirrored vertical',
              5 => 'Mirrored horizontal then rotated 90 CCW',
              6 => 'Rotated 90 CW',
              7 => 'Mirrored horizontal then rotated 90 CW',
              8 => 'Rotated 90 CCW'}),
    0x0115 => TagName.new('SamplesPerPixel'),
    0x0116 => TagName.new('RowsPerStrip'),
    0x0117 => TagName.new('StripByteCounts'),
    0x011A => TagName.new('XResolution'),
    0x011B => TagName.new('YResolution'),
    0x011C => TagName.new('PlanarConfiguration'),
    0x011D => TagName.new('PageName', self.method(:ascii_bytes_to_filtered_string)),
    0x0128 => TagName.new('ResolutionUnit',
             { 1 => 'Not Absolute',
               2 => 'Pixels/Inch',
               3 => 'Pixels/Centimeter' }),
    0x012D => TagName.new('TransferFunction'),
    0x0131 => TagName.new('Software'),
    0x0132 => TagName.new('DateTime'),
    0x013B => TagName.new('Artist'),
    0x013E => TagName.new('WhitePoint'),
    0x013F => TagName.new('PrimaryChromaticities'),
    0x0156 => TagName.new('TransferRange'),
    0x0200 => TagName.new('JPEGProc'),
    0x0201 => TagName.new('JPEGInterchangeFormat'),
    0x0202 => TagName.new('JPEGInterchangeFormatLength'),
    0x0211 => TagName.new('YCbCrCoefficients'),
    0x0212 => TagName.new('YCbCrSubSampling'),
    0x0213 => TagName.new('YCbCrPositioning',
             {1 => 'Centered',
              2 => 'Co-sited'}),
    0x0214 => TagName.new('ReferenceBlackWhite'),
    
    0x4746 => TagName.new('Rating'),
    
    0x828D => TagName.new('CFARepeatPatternDim'),
    0x828E => TagName.new('CFAPattern'),
    0x828F => TagName.new('BatteryLevel'),
    0x8298 => TagName.new('Copyright'),
    0x829A => TagName.new('ExposureTime'),
    0x829D => TagName.new('FNumber'),
    0x83BB => TagName.new('IPTC/NAA'),
    0x8769 => TagName.new('ExifOffset'),
    0x8773 => TagName.new('InterColorProfile'),
    0x8822 => TagName.new('ExposureProgram',
             {0 => 'Unidentified',
              1 => 'Manual',
              2 => 'Program Normal',
              3 => 'Aperture Priority',
              4 => 'Shutter Priority',
              5 => 'Program Creative',
              6 => 'Program Action',
              7 => 'Portrait Mode',
              8 => 'Landscape Mode'}),
    0x8824 => TagName.new('SpectralSensitivity'),
    0x8825 => TagName.new('GPSInfo'),
    0x8827 => TagName.new('ISOSpeedRatings'),
    0x8828 => TagName.new('OECF'),
    0x9000 => TagName.new('ExifVersion', self.method(:ascii_bytes_to_filtered_string)),
    0x9003 => TagName.new('DateTimeOriginal'),
    0x9004 => TagName.new('DateTimeDigitized'),
    0x9101 => TagName.new('ComponentsConfiguration',
             {0 => '',
              1 => 'Y',
              2 => 'Cb',
              3 => 'Cr',
              4 => 'Red',
              5 => 'Green',
              6 => 'Blue'}),
    0x9102 => TagName.new('CompressedBitsPerPixel'),
    0x9201 => TagName.new('ShutterSpeedValue'),
    0x9202 => TagName.new('ApertureValue'),
    0x9203 => TagName.new('BrightnessValue'),
    0x9204 => TagName.new('ExposureBiasValue'),
    0x9205 => TagName.new('MaxApertureValue'),
    0x9206 => TagName.new('SubjectDistance'),
    0x9207 => TagName.new('MeteringMode',
             {0 => 'Unidentified',
              1 => 'Average',
              2 => 'CenterWeightedAverage',
              3 => 'Spot',
              4 => 'MultiSpot',
              5 => 'Pattern'}),
    0x9208 => TagName.new('LightSource',
             {0 => 'Unknown',
              1 => 'Daylight',
              2 => 'Fluorescent',
              3 => 'Tungsten',
              9 => 'Fine Weather',
              10 => 'Flash',
              11 => 'Shade',
              12 => 'Daylight Fluorescent',
              13 => 'Day White Fluorescent',
              14 => 'Cool White Fluorescent',
              15 => 'White Fluorescent',
              17 => 'Standard Light A',
              18 => 'Standard Light B',
              19 => 'Standard Light C',
              20 => 'D55',
              21 => 'D65',
              22 => 'D75',
              255 => 'Other'}),
    0x9209 => TagName.new('Flash',
             {0 => 'No',
              1 => 'Fired',
              5 => 'Fired (?)', # no return sensed
              7 => 'Fired (!)', # return sensed
              9 => 'Fill Fired',
              13 => 'Fill Fired (?)',
              15 => 'Fill Fired (!)',
              16 => 'Off',
              24 => 'Auto Off',
              25 => 'Auto Fired',
              29 => 'Auto Fired (?)',
              31 => 'Auto Fired (!)',
              32 => 'Not Available'}),
    0x920A => TagName.new('FocalLength'),
    0x9214 => TagName.new('SubjectArea'),
    0x927C => TagName.new('MakerNote'),
    0x9286 => TagName.new('UserComment', self.method(:filter_encoded_string)),
    0x9290 => TagName.new('SubSecTime'),
    0x9291 => TagName.new('SubSecTimeOriginal'),
    0x9292 => TagName.new('SubSecTimeDigitized'),
    
    # used by Windows Explorer
    0x9C9B => TagName.new('XPTitle'),
    0x9C9C => TagName.new('XPComment'),
    0x9C9D => TagName.new('XPAuthor'), #(ignored by Windows Explorer if Artist exists)
    0x9C9E => TagName.new('XPKeywords'),
    0x9C9F => TagName.new('XPSubject'),

    0xA000 => TagName.new('FlashPixVersion', self.method(:ascii_bytes_to_filtered_string)),
    0xA001 => TagName.new('ColorSpace',
             {1 => 'sRGB',
              2 => 'Adobe RGB',
              65535 => 'Uncalibrated'}),
    0xA002 => TagName.new('ExifImageWidth'),
    0xA003 => TagName.new('ExifImageLength'),
    0xA005 => TagName.new('InteroperabilityOffset'),
    0xA20B => TagName.new('FlashEnergy'),               # 0x920B in TIFF/EP
    0xA20C => TagName.new('SpatialFrequencyResponse'),  # 0x920C
    0xA20E => TagName.new('FocalPlaneXResolution'),     # 0x920E
    0xA20F => TagName.new('FocalPlaneYResolution'),     # 0x920F
    0xA210 => TagName.new('FocalPlaneResolutionUnit'),  # 0x9210
    0xA214 => TagName.new('SubjectLocation'),           # 0x9214
    0xA215 => TagName.new('ExposureIndex'),             # 0x9215
    0xA217 => TagName.new('SensingMethod',                # 0x9217
             {1 => 'Not defined',
              2 => 'One-chip color area',
              3 => 'Two-chip color area',
              4 => 'Three-chip color area',
              5 => 'Color sequential area',
              7 => 'Trilinear',
              8 => 'Color sequential linear'}),             
    0xA300 => TagName.new('FileSource',
             {1 => 'Film Scanner',
              2 => 'Reflection Print Scanner',
              3 => 'Digital Camera'}),
    0xA301 => TagName.new('SceneType',
             {1 => 'Directly Photographed'}),
    0xA302 => TagName.new('CVAPattern'),
    0xA401 => TagName.new('CustomRendered',
             {0 => 'Normal',
              1 => 'Custom'}),
    0xA402 => TagName.new('ExposureMode',
             {0 => 'Auto Exposure',
              1 => 'Manual Exposure',
              2 => 'Auto Bracket'}),
    0xA403 => TagName.new('WhiteBalance',
             {0 => 'Auto',
              1 => 'Manual'}),
    0xA404 => TagName.new('DigitalZoomRatio'),
    0xA405 => TagName.new('FocalLengthIn35mmFilm'),
    0xA406 => TagName.new('SceneCaptureType',
             {0 => 'Standard',
              1 => 'Landscape',
              2 => 'Portrait',
              3 => 'Night)'}),
    0xA407 => TagName.new('GainControl',
             {0 => 'None',
              1 => 'Low gain up',
              2 => 'High gain up',
              3 => 'Low gain down',
              4 => 'High gain down'}),
    0xA408 => TagName.new('Contrast',
             {0 => 'Normal',
              1 => 'Soft',
              2 => 'Hard'}),
    0xA409 => TagName.new('Saturation',
             {0 => 'Normal',
              1 => 'Soft',
              2 => 'Hard'}),
    0xA40A => TagName.new('Sharpness',
             {0 => 'Normal',
              1 => 'Soft',
              2 => 'Hard'}),
    0xA40B => TagName.new('DeviceSettingDescription'),
    0xA40C => TagName.new('SubjectDistanceRange'),
    0xA500 => TagName.new('Gamma'),
    0xC4A5 => TagName.new('PrintIM'),
    0xEA1C =>	TagName.new('Padding')
    }

# interoperability tags
INTR_TAGS = {
    0x0001 => TagName.new('InteroperabilityIndex'),
    0x0002 => TagName.new('InteroperabilityVersion'),
    0x1000 => TagName.new('RelatedImageFileFormat'),
    0x1001 => TagName.new('RelatedImageWidth'),
    0x1002 => TagName.new('RelatedImageLength')
    }

# Ignore these tags when quick processing
# 0x927C is MakerNote Tags
# 0x9286 is user comment
IGNORE_TAGS = [0x9286, 0x927C]


MAKERNOTE_OLYMPUS_TAGS = {
    # ah HAH! those sneeeeeaky bastids! this is how they get past the fact
    # that a JPEG thumbnail is not allowed in an uncompressed TIFF file
    0x0100 => TagName.new('JPEGThumbnail'),
    0x0200 => TagName.new('SpecialMode', self.method(:olympus_special_mode)),
    0x0201 => TagName.new('JPEGQual',
             {1 => 'SQ',
              2 => 'HQ',
              3 => 'SHQ'}),
    0x0202 => TagName.new('Macro',
             {0 => 'Normal',
             1 => 'Macro',
             2 => 'SuperMacro'}),
    0x0203 => TagName.new('BWMode',
             {0 => 'Off',
             1 => 'On'}),
    0x0204 => TagName.new('DigitalZoom'),
    0x0205 => TagName.new('FocalPlaneDiagonal'),
    0x0206 => TagName.new('LensDistortionParams'),
    0x0207 => TagName.new('SoftwareRelease'),
    0x0208 => TagName.new('PictureInfo'),
    0x0209 => TagName.new('CameraID', self.method(:ascii_bytes_to_filtered_string)), # print as string
    0x0F00 => TagName.new('DataDump'),
    0x0300 => TagName.new('PreCaptureFrames'),
    0x0404 => TagName.new('SerialNumber'),
    0x1000 => TagName.new('ShutterSpeedValue'),
    0x1001 => TagName.new('ISOValue'),
    0x1002 => TagName.new('ApertureValue'),
    0x1003 => TagName.new('BrightnessValue'),
    0x1004 => TagName.new('FlashMode'),
    0x1004 => TagName.new('FlashMode',
       {2 => 'On',
        3 => 'Off'}),
    0x1005 => TagName.new('FlashDevice',
       {0 => 'None',
        1 => 'Internal',
        4 => 'External',
        5 => 'Internal + External'}),
    0x1006 => TagName.new('ExposureCompensation'),
    0x1007 => TagName.new('SensorTemperature'),
    0x1008 => TagName.new('LensTemperature'),
    0x100b => TagName.new('FocusMode',
       {0 => 'Auto',
        1 => 'Manual'}),
    0x1017 => TagName.new('RedBalance'),
    0x1018 => TagName.new('BlueBalance'),
    0x101a => TagName.new('SerialNumber'),
    0x1023 => TagName.new('FlashExposureComp'),
    0x1026 => TagName.new('ExternalFlashBounce',
       {0 => 'No',
        1 => 'Yes'}),
    0x1027 => TagName.new('ExternalFlashZoom'),
    0x1028 => TagName.new('ExternalFlashMode'),
    0x1029 => TagName.new('Contrast 	int16u',
       {0 => 'High',
        1 => 'Normal',
        2 => 'Low'}),
    0x102a => TagName.new('SharpnessFactor'),
    0x102b => TagName.new('ColorControl'),
    0x102c => TagName.new('ValidBits'),
    0x102d => TagName.new('CoringFilter'),
    0x102e => TagName.new('OlympusImageWidth'),
    0x102f => TagName.new('OlympusImageHeight'),
    0x1034 => TagName.new('CompressionRatio'),
    0x1035 => TagName.new('PreviewImageValid',
       {0 => 'No',
        1 => 'Yes'}),
    0x1036 => TagName.new('PreviewImageStart'),
    0x1037 => TagName.new('PreviewImageLength'),
    0x1039 => TagName.new('CCDScanMode',
       {0 => 'Interlaced',
        1 => 'Progressive'}),
    0x103a => TagName.new('NoiseReduction',
       {0 => 'Off',
        1 => 'On'}),
    0x103b => TagName.new('InfinityLensStep'),
    0x103c => TagName.new('NearLensStep'),

    # TODO - these need extra definitions
    # http =>//search.cpan.org/src/EXIFTOOL/Image-ExifTool-6.90/html/TagNames/Olympus.html
    0x2010 => TagName.new('Equipment'),
    0x2020 => TagName.new('CameraSettings'),
    0x2030 => TagName.new('RawDevelopment'),
    0x2040 => TagName.new('ImageProcessing'),
    0x2050 => TagName.new('FocusInfo'),
    0x3000 => TagName.new('RawInfo '),
    }

# 0x2020 CameraSettings
MAKERNOTE_OLYMPUS_TAG_0x2020={
    0x0100 => TagName.new('PreviewImageValid',
             {0 => 'No',
              1 => 'Yes'}),
    0x0101 => TagName.new('PreviewImageStart'),
    0x0102 => TagName.new('PreviewImageLength'),
    0x0200 => TagName.new('ExposureMode',
             {1 => 'Manual',
              2 => 'Program',
              3 => 'Aperture-priority AE',
              4 => 'Shutter speed priority AE',
              5 => 'Program-shift'}),
    0x0201 => TagName.new('AELock',
             {0 => 'Off',
              1 => 'On'}),
    0x0202 => TagName.new('MeteringMode',
             {2 => 'Center Weighted',
              3 => 'Spot',
              5 => 'ESP',
              261 => 'Pattern+AF',
              515 => 'Spot+Highlight control',
              1027 => 'Spot+Shadow control'}),
    0x0300 => TagName.new('MacroMode',
             {0 => 'Off',
              1 => 'On'}),
    0x0301 => TagName.new('FocusMode',
             {0 => 'Single AF',
              1 => 'Sequential shooting AF',
              2 => 'Continuous AF',
              3 => 'Multi AF',
              10 => 'MF'}),
    0x0302 => TagName.new('FocusProcess',
             {0 => 'AF Not Used',
              1 => 'AF Used'}),
    0x0303 => TagName.new('AFSearch',
             {0 => 'Not Ready',
              1 => 'Ready'}),
    0x0304 => TagName.new('AFAreas'),
    0x0401 => TagName.new('FlashExposureCompensation'),
    0x0500 => TagName.new('WhiteBalance2',
             {0 => 'Auto',
             16 => '7500K (Fine Weather with Shade)',
             17 => '6000K (Cloudy)',
             18 => '5300K (Fine Weather)',
             20 => '3000K (Tungsten light)',
             21 => '3600K (Tungsten light-like)',
             33 => '6600K (Daylight fluorescent)',
             34 => '4500K (Neutral white fluorescent)',
             35 => '4000K (Cool white fluorescent)',
             48 => '3600K (Tungsten light-like)',
             256 => 'Custom WB 1',
             257 => 'Custom WB 2',
             258 => 'Custom WB 3',
             259 => 'Custom WB 4',
             512 => 'Custom WB 5400K',
             513 => 'Custom WB 2900K',
             514 => 'Custom WB 8000K', }),
    0x0501 => TagName.new('WhiteBalanceTemperature'),
    0x0502 => TagName.new('WhiteBalanceBracket'),
    0x0503 => TagName.new('CustomSaturation'), # (3 numbers => 1. CS Value, 2. Min, 3. Max)
    0x0504 => TagName.new('ModifiedSaturation',
             {0 => 'Off',
              1 => 'CM1 (Red Enhance)',
              2 => 'CM2 (Green Enhance)',
              3 => 'CM3 (Blue Enhance)',
              4 => 'CM4 (Skin Tones)'}),
    0x0505 => TagName.new('ContrastSetting'), # (3 numbers => 1. Contrast, 2. Min, 3. Max)
    0x0506 => TagName.new('SharpnessSetting'), # (3 numbers => 1. Sharpness, 2. Min, 3. Max)
    0x0507 => TagName.new('ColorSpace',
             {0 => 'sRGB',
              1 => 'Adobe RGB',
              2 => 'Pro Photo RGB'}),
    0x0509 => TagName.new('SceneMode',
             {0 => 'Standard',
              6 => 'Auto',
              7 => 'Sport',
              8 => 'Portrait',
              9 => 'Landscape+Portrait',
             10 => 'Landscape',
             11 => 'Night scene',
             13 => 'Panorama',
             16 => 'Landscape+Portrait',
             17 => 'Night+Portrait',
             19 => 'Fireworks',
             20 => 'Sunset',
             22 => 'Macro',
             25 => 'Documents',
             26 => 'Museum',
             28 => 'Beach&Snow',
             30 => 'Candle',
             35 => 'Underwater Wide1',
             36 => 'Underwater Macro',
             39 => 'High Key',
             40 => 'Digital Image Stabilization',
             44 => 'Underwater Wide2',
             45 => 'Low Key',
             46 => 'Children',
             48 => 'Nature Macro'}),
    0x050a => TagName.new('NoiseReduction',
             {0 => 'Off',
              1 => 'Noise Reduction',
              2 => 'Noise Filter',
              3 => 'Noise Reduction + Noise Filter',
              4 => 'Noise Filter (ISO Boost)',
              5 => 'Noise Reduction + Noise Filter (ISO Boost)'}),
    0x050b => TagName.new('DistortionCorrection',
             {0 => 'Off',
              1 => 'On'}),
    0x050c => TagName.new('ShadingCompensation',
             {0 => 'Off',
              1 => 'On'}),
    0x050d => TagName.new('CompressionFactor'),
    0x050f => TagName.new('Gradation',
             {'-1 -1 1' => 'Low Key',
              '0 -1 1' => 'Normal',
              '1 -1 1' => 'High Key'}),
    0x0520 => TagName.new('PictureMode',
             {1 => 'Vivid',
              2 => 'Natural',
              3 => 'Muted',
              256 => 'Monotone',
              512 => 'Sepia'}),
    0x0521 => TagName.new('PictureModeSaturation'),
    0x0522 => TagName.new('PictureModeHue?'),
    0x0523 => TagName.new('PictureModeContrast'),
    0x0524 => TagName.new('PictureModeSharpness'),
    0x0525 => TagName.new('PictureModeBWFilter',
             {0 => 'n/a',
              1 => 'Neutral',
              2 => 'Yellow',
              3 => 'Orange',
              4 => 'Red',
              5 => 'Green'}),
    0x0526 => TagName.new('PictureModeTone',
             {0 => 'n/a',
              1 => 'Neutral',
              2 => 'Sepia',
              3 => 'Blue',
              4 => 'Purple',
              5 => 'Green'}),
    0x0600 => TagName.new('Sequence'), # 2 or 3 numbers => 1. Mode, 2. Shot number, 3. Mode bits
    0x0601 => TagName.new('PanoramaMode'), # (2 numbers => 1. Mode, 2. Shot number)
    0x0603 => TagName.new('ImageQuality2',
             {1 => 'SQ',
              2 => 'HQ',
              3 => 'SHQ',
              4 => 'RAW'}),
    0x0901 => TagName.new('ManometerReading')
    }


MAKERNOTE_CASIO_TAGS={
    0x0001 => TagName.new('RecordingMode',
             {1 => 'Single Shutter',
              2 => 'Panorama',
              3 => 'Night Scene',
              4 => 'Portrait',
              5 => 'Landscape'}),
    0x0002 => TagName.new('Quality',
             {1 => 'Economy',
              2 => 'Normal',
              3 => 'Fine'}),
    0x0003 => TagName.new('FocusingMode',
             {2 => 'Macro',
              3 => 'Auto Focus',
              4 => 'Manual Focus',
              5 => 'Infinity'}),
    0x0004 => TagName.new('FlashMode',
             {1 => 'Auto',
              2 => 'On',
              3 => 'Off',
              4 => 'Red Eye Reduction'}),
    0x0005 => TagName.new('FlashIntensity',
             {11 => 'Weak',
              13 => 'Normal',
              15 => 'Strong'}),
    0x0006 => TagName.new('Object Distance'),
    0x0007 => TagName.new('WhiteBalance',
             {1 => 'Auto',
              2 => 'Tungsten',
              3 => 'Daylight',
              4 => 'Fluorescent',
              5 => 'Shade',
              129 => 'Manual'}),
    0x000B => TagName.new('Sharpness',
             {0 => 'Normal',
              1 => 'Soft',
              2 => 'Hard'}),
    0x000C => TagName.new('Contrast',
             {0 => 'Normal',
              1 => 'Low',
              2 => 'High'}),
    0x000D => TagName.new('Saturation',
             {0 => 'Normal',
              1 => 'Low',
              2 => 'High'}),
    0x0014 => TagName.new('CCDSpeed',
             {64 => 'Normal',
              80 => 'Normal',
              100 => 'High',
              125 => '+1.0',
              244 => '+3.0',
              250 => '+2.0'})
    }

MAKERNOTE_FUJIFILM_TAGS={
    0x0000 => TagName.new('NoteVersion', self.method(:ascii_bytes_to_filtered_string)),
    0x1000 => TagName.new('Quality'),
    0x1001 => TagName.new('Sharpness',
             {1 => 'Soft',
              2 => 'Soft',
              3 => 'Normal',
              4 => 'Hard',
              5 => 'Hard'}),
    0x1002 => TagName.new('WhiteBalance',
             {0 => 'Auto',
              256 => 'Daylight',
              512 => 'Cloudy',
              768 => 'DaylightColor-Fluorescent',
              769 => 'DaywhiteColor-Fluorescent',
              770 => 'White-Fluorescent',
              1024 => 'Incandescent',
              3840 => 'Custom'}),
    0x1003 => TagName.new('Color',
             {0 => 'Normal',
              256 => 'High',
              512 => 'Low'}),
    0x1004 => TagName.new('Tone',
             {0 => 'Normal',
              256 => 'High',
              512 => 'Low'}),
    0x1010 => TagName.new('FlashMode',
             {0 => 'Auto',
              1 => 'On',
              2 => 'Off',
              3 => 'Red Eye Reduction'}),
    0x1011 => TagName.new('FlashStrength'),
    0x1020 => TagName.new('Macro',
             {0 => 'Off',
              1 => 'On'}),
    0x1021 => TagName.new('FocusMode',
             {0 => 'Auto',
              1 => 'Manual'}),
    0x1030 => TagName.new('SlowSync',
             {0 => 'Off',
              1 => 'On'}),
    0x1031 => TagName.new('PictureMode',
             {0 => 'Auto',
              1 => 'Portrait',
              2 => 'Landscape',
              4 => 'Sports',
              5 => 'Night',
              6 => 'Program AE',
              256 => 'Aperture Priority AE',
              512 => 'Shutter Priority AE',
              768 => 'Manual Exposure'}),
    0x1100 => TagName.new('MotorOrBracket',
             {0 => 'Off',
              1 => 'On'}),
    0x1300 => TagName.new('BlurWarning',
             {0 => 'Off',
              1 => 'On'}),
    0x1301 => TagName.new('FocusWarning',
             {0 => 'Off',
              1 => 'On'}),
    0x1302 => TagName.new('AEWarning',
             {0 => 'Off',
              1 => 'On'})
    }

MAKERNOTE_CANON_TAGS = {
    0x0006 => TagName.new('ImageType'),
    0x0007 => TagName.new('FirmwareVersion'),
    0x0008 => TagName.new('ImageNumber'),
    0x0009 => TagName.new('OwnerName')
    }

# this is in element offset, name, optional value dictionary format
MAKERNOTE_CANON_TAG_0x001 = {
    1 => TagName.new('Macromode',
        {1 => 'Macro',
         2 => 'Normal'}),
    2 => TagName.new('SelfTimer'),
    3 => TagName.new('Quality',
        {2 => 'Normal',
         3 => 'Fine',
         5 => 'Superfine'}),
    4 => TagName.new('FlashMode',
        {0 => 'Flash Not Fired',
         1 => 'Auto',
         2 => 'On',
         3 => 'Red-Eye Reduction',
         4 => 'Slow Synchro',
         5 => 'Auto + Red-Eye Reduction',
         6 => 'On + Red-Eye Reduction',
         16 => 'external flash'}),
    5 => TagName.new('ContinuousDriveMode',
        {0 => 'Single Or Timer',
         1 => 'Continuous'}),
    7 => TagName.new('FocusMode',
        {0 => 'One-Shot',
         1 => 'AI Servo',
         2 => 'AI Focus',
         3 => 'MF',
         4 => 'Single',
         5 => 'Continuous',
         6 => 'MF'}),
    10 => TagName.new('ImageSize',
         {0 => 'Large',
          1 => 'Medium',
          2 => 'Small'}),
    11 => TagName.new('EasyShootingMode',
         {0 => 'Full Auto',
          1 => 'Manual',
          2 => 'Landscape',
          3 => 'Fast Shutter',
          4 => 'Slow Shutter',
          5 => 'Night',
          6 => 'B&W',
          7 => 'Sepia',
          8 => 'Portrait',
          9 => 'Sports',
          10 => 'Macro/Close-Up',
          11 => 'Pan Focus'}),
    12 => TagName.new('DigitalZoom',
         {0 => 'None',
          1 => '2x',
          2 => '4x'}),
    13 => TagName.new('Contrast',
         {0xFFFF => 'Low',
          0 => 'Normal',
          1 => 'High'}),
    14 => TagName.new('Saturation',
         {0xFFFF => 'Low',
          0 => 'Normal',
          1 => 'High'}),
    15 => TagName.new('Sharpness',
         {0xFFFF => 'Low',
          0 => 'Normal',
          1 => 'High'}),
    16 => TagName.new('ISO',
         {0 => 'See ISOSpeedRatings Tag',
          15 => 'Auto',
          16 => '50',
          17 => '100',
          18 => '200',
          19 => '400'}),
    17 => TagName.new('MeteringMode',
         {3 => 'Evaluative',
          4 => 'Partial',
          5 => 'Center-weighted'}),
    18 => TagName.new('FocusType',
         {0 => 'Manual',
          1 => 'Auto',
          3 => 'Close-Up (Macro)',
          8 => 'Locked (Pan Mode)'}),
    19 => TagName.new('AFPointSelected',
         {0x3000 => 'None (MF)',
          0x3001 => 'Auto-Selected',
          0x3002 => 'Right',
          0x3003 => 'Center',
          0x3004 => 'Left'}),
    20 => TagName.new('ExposureMode',
         {0 => 'Easy Shooting',
          1 => 'Program',
          2 => 'Tv-priority',
          3 => 'Av-priority',
          4 => 'Manual',
          5 => 'A-DEP'}),
    23 => TagName.new('LongFocalLengthOfLensInFocalUnits'),
    24 => TagName.new('ShortFocalLengthOfLensInFocalUnits'),
    25 => TagName.new('FocalUnitsPerMM'),
    28 => TagName.new('FlashActivity',
         {0 => 'Did Not Fire',
          1 => 'Fired'}),
    29 => TagName.new('FlashDetails',
         {14 => 'External E-TTL',
          13 => 'Internal Flash',
          11 => 'FP Sync Used',
          7 => '2nd("Rear")-Curtain Sync Used',
          4 => 'FP Sync Enabled'}),
    32 => TagName.new('FocusMode',
         {0 => 'Single',
          1 => 'Continuous'})
    }

MAKERNOTE_CANON_TAG_0x004 = {
    7 => TagName.new('WhiteBalance',
        {0 => 'Auto',
         1 => 'Sunny',
         2 => 'Cloudy',
         3 => 'Tungsten',
         4 => 'Fluorescent',
         5 => 'Flash',
         6 => 'Custom'}),
    9 => TagName.new('SequenceNumber'),
    14 => TagName.new('AFPointUsed'),
    15 => TagName.new('FlashBias',
         {0xFFC0 => '-2 EV',
          0xFFCC => '-1.67 EV',
          0xFFD0 => '-1.50 EV',
          0xFFD4 => '-1.33 EV',
          0xFFE0 => '-1 EV',
          0xFFEC => '-0.67 EV',
          0xFFF0 => '-0.50 EV',
          0xFFF4 => '-0.33 EV',
          0x0000 => '0 EV',
          0x000C => '0.33 EV',
          0x0010 => '0.50 EV',
          0x0014 => '0.67 EV',
          0x0020 => '1 EV',
          0x002C => '1.33 EV',
          0x0030 => '1.50 EV',
          0x0034 => '1.67 EV',
          0x0040 => '2 EV'}),
    19 => TagName.new('SubjectDistance')
    }

# Nikon E99x MakerNote Tags
MAKERNOTE_NIKON_NEWER_TAGS={
    0x0001 => TagName.new('MakernoteVersion', self.method(:ascii_bytes_to_filtered_string)),	# Sometimes binary
    0x0002 => TagName.new('ISOSetting', self.method(:ascii_bytes_to_filtered_string)),
    0x0003 => TagName.new('ColorMode'),
    0x0004 => TagName.new('Quality'),
    0x0005 => TagName.new('Whitebalance'),
    0x0006 => TagName.new('ImageSharpening'),
    0x0007 => TagName.new('FocusMode'),
    0x0008 => TagName.new('FlashSetting'),
    0x0009 => TagName.new('AutoFlashMode'),
    0x000B => TagName.new('WhiteBalanceBias'),
    0x000C => TagName.new('WhiteBalanceRBCoeff'),
    0x000D => TagName.new('ProgramShift', self.method(:nikon_ev_bias)),
    # Nearly the same as the other EV vals, but step size is 1/12 EV (?)
    0x000E => TagName.new('ExposureDifference', self.method(:nikon_ev_bias)),
    0x000F => TagName.new('ISOSelection'),
    0x0011 => TagName.new('NikonPreview'),
    0x0012 => TagName.new('FlashCompensation', self.method(:nikon_ev_bias)),
    0x0013 => TagName.new('ISOSpeedRequested'),
    0x0016 => TagName.new('PhotoCornerCoordinates'),
    0x0018 => TagName.new('FlashBracketCompensationApplied', self.method(:nikon_ev_bias)),
    0x0019 => TagName.new('AEBracketCompensationApplied'),
    0x001A => TagName.new('ImageProcessing'),
    0x001B => TagName.new('CropHiSpeed'),
    0x001D => TagName.new('SerialNumber'),	# Conflict with 0x00A0 ?
    0x001E => TagName.new('ColorSpace'),
    0x001F => TagName.new('VRInfo'),
    0x0020 => TagName.new('ImageAuthentication'),
    0x0022 => TagName.new('ActiveDLighting'),
    0x0023 => TagName.new('PictureControl'),
    0x0024 => TagName.new('WorldTime'),
    0x0025 => TagName.new('ISOInfo'),
    0x0080 => TagName.new('ImageAdjustment'),
    0x0081 => TagName.new('ToneCompensation'),
    0x0082 => TagName.new('AuxiliaryLens'),
    0x0083 => TagName.new('LensType'),
    0x0084 => TagName.new('LensMinMaxFocalMaxAperture'),
    0x0085 => TagName.new('ManualFocusDistance'),
    0x0086 => TagName.new('DigitalZoomFactor'),
    0x0087 => TagName.new('FlashMode',
             {0x00 => 'Did Not Fire',
              0x01 => 'Fired, Manual',
              0x07 => 'Fired, External',
              0x08 => 'Fired, Commander Mode ',
              0x09 => 'Fired, TTL Mode'}),
    0x0088 => TagName.new('AFFocusPosition',
             {0x0000 => 'Center',
              0x0100 => 'Top',
              0x0200 => 'Bottom',
              0x0300 => 'Left',
              0x0400 => 'Right'}),
    0x0089 => TagName.new('BracketingMode',
             {0x00 => 'Single frame, no bracketing',
              0x01 => 'Continuous, no bracketing',
              0x02 => 'Timer, no bracketing',
              0x10 => 'Single frame, exposure bracketing',
              0x11 => 'Continuous, exposure bracketing',
              0x12 => 'Timer, exposure bracketing',
              0x40 => 'Single frame, white balance bracketing',
              0x41 => 'Continuous, white balance bracketing',
              0x42 => 'Timer, white balance bracketing'}),
    0x008A => TagName.new('AutoBracketRelease'),
    0x008B => TagName.new('LensFStops'),
    0x008C => TagName.new('NEFCurve1'),	# ExifTool calls this 'ContrastCurve'
    0x008D => TagName.new('ColorMode'),
    0x008F => TagName.new('SceneMode'),
    0x0090 => TagName.new('LightingType'),
    0x0091 => TagName.new('ShotInfo'),	# First 4 bytes are a version number in ASCII
    0x0092 => TagName.new('HueAdjustment'),
    # ExifTool calls this 'NEFCompression', should be 1-4
    0x0093 => TagName.new('Compression'),
    0x0094 => TagName.new('Saturation',
             {-3 => 'B&W',
              -2 => '-2',
              -1 => '-1',
              0 => '0',
              1 => '1',
              2 => '2'}),
    0x0095 => TagName.new('NoiseReduction'),
    0x0096 => TagName.new('NEFCurve2'),	# ExifTool calls this 'LinearizationTable'
    0x0097 => TagName.new('ColorBalance'),	# First 4 bytes are a version number in ASCII
    0x0098 => TagName.new('LensData'),	# First 4 bytes are a version number in ASCII
    0x0099 => TagName.new('RawImageCenter'),
    0x009A => TagName.new('SensorPixelSize'),
    0x009C => TagName.new('Scene Assist'),
    0x009E => TagName.new('RetouchHistory'),
    0x00A0 => TagName.new('SerialNumber'),
    0x00A2 => TagName.new('ImageDataSize'),
    # 00A3 => unknown - a single byte 0
    # 00A4 => In NEF, looks like a 4 byte ASCII version number ('0200')
    0x00A5 => TagName.new('ImageCount'),
    0x00A6 => TagName.new('DeletedImageCount'),
    0x00A7 => TagName.new('TotalShutterReleases'),
    # First 4 bytes are a version number in ASCII, with version specific
    # info to follow.  Its hard to treat it as a string due to embedded nulls.
    0x00A8 => TagName.new('FlashInfo'),
    0x00A9 => TagName.new('ImageOptimization'),
    0x00AA => TagName.new('Saturation'),
    0x00AB => TagName.new('DigitalVariProgram'),
    0x00AC => TagName.new('ImageStabilization'),
    0x00AD => TagName.new('Responsive AF'),	# 'AFResponse'
    0x00B0 => TagName.new('MultiExposure'),
    0x00B1 => TagName.new('HighISONoiseReduction'),
    0x00B7 => TagName.new('AFInfo'),
    0x00B8 => TagName.new('FileInfo'),
    # 00B9 => unknown
    0x0100 => TagName.new('DigitalICE'),
    0x0103 => TagName.new('PreviewCompression',
             {1 => 'Uncompressed',
              2 => 'CCITT 1D',
              3 => 'T4/Group 3 Fax',
              4 => 'T6/Group 4 Fax',
              5 => 'LZW',
              6 => 'JPEG (old-style)',
              7 => 'JPEG',
              8 => 'Adobe Deflate',
              9 => 'JBIG B&W',
              10 => 'JBIG Color',
              32766 => 'Next',
              32769 => 'Epson ERF Compressed',
              32771 => 'CCIRLEW',
              32773 => 'PackBits',
              32809 => 'Thunderscan',
              32895 => 'IT8CTPAD',
              32896 => 'IT8LW',
              32897 => 'IT8MP',
              32898 => 'IT8BL',
              32908 => 'PixarFilm',
              32909 => 'PixarLog',
              32946 => 'Deflate',
              32947 => 'DCS',
              34661 => 'JBIG',
              34676 => 'SGILog',
              34677 => 'SGILog24',
              34712 => 'JPEG 2000',
              34713 => 'Nikon NEF Compressed',
              65000 => 'Kodak DCR Compressed',
              65535 => 'Pentax PEF Compressed',}),
    0x0201 => TagName.new('PreviewImageStart'),
    0x0202 => TagName.new('PreviewImageLength'),
    0x0213 => TagName.new('PreviewYCbCrPositioning',
             {1 => 'Centered',
              2 => 'Co-sited'}), 
    0x0010 => TagName.new('DataDump'),
    }

MAKERNOTE_NIKON_OLDER_TAGS = {
    0x0003 => TagName.new('Quality',
             {1 => 'VGA Basic',
              2 => 'VGA Normal',
              3 => 'VGA Fine',
              4 => 'SXGA Basic',
              5 => 'SXGA Normal',
              6 => 'SXGA Fine'}),
    0x0004 => TagName.new('ColorMode',
             {1 => 'Color',
              2 => 'Monochrome'}),
    0x0005 => TagName.new('ImageAdjustment',
             {0 => 'Normal',
              1 => 'Bright+',
              2 => 'Bright-',
              3 => 'Contrast+',
              4 => 'Contrast-'}),
    0x0006 => TagName.new('CCDSpeed',
             {0 => 'ISO 80',
              2 => 'ISO 160',
              4 => 'ISO 320',
              5 => 'ISO 100'}),
    0x0007 => TagName.new('WhiteBalance',
             {0 => 'Auto',
              1 => 'Preset',
              2 => 'Daylight',
              3 => 'Incandescent',
              4 => 'Fluorescent',
              5 => 'Cloudy',
              6 => 'Speed Light'}),
    }

end # ::Exif
end # ::Properties
end # ::Image
end # ::Cul