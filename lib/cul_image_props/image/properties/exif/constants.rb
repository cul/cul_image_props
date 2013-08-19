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
    FieldType.new(1, 'SB', 'Signed Byte', true),
    FieldType.new(1, 'U', 'Undefined'),
    FieldType.new(2, 'SS', 'Signed Short', true),
    FieldType.new(4, 'SL', 'Signed Long', true),
    FieldType.new(8, 'SR', 'Signed Ratio', true)
    ]

# dictionary of main EXIF tag names
EXIF_TAGS = {
    0x0100 => TagEntry.new('ImageWidth'),
    0x0101 => TagEntry.new('ImageLength'),
    0x0102 => TagEntry.new('BitsPerSample'),
    0x0103 => TagEntry.new('Compression',
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
    0x0106 => TagEntry.new('PhotometricInterpretation'),
    0x0107 => TagEntry.new('Thresholding'),
    0x010A => TagEntry.new('FillOrder'),
    0x010D => TagEntry.new('DocumentName'),
    0x010E => TagEntry.new('ImageDescription'),
    0x010F => TagEntry.new('Make'),
    0x0110 => TagEntry.new('Model'),
    0x0111 => TagEntry.new('StripOffsets'),
    0x0112 => TagEntry.new('Orientation',
             {1 => 'Horizontal (normal)',
              2 => 'Mirrored horizontal',
              3 => 'Rotated 180',
              4 => 'Mirrored vertical',
              5 => 'Mirrored horizontal then rotated 90 CCW',
              6 => 'Rotated 90 CW',
              7 => 'Mirrored horizontal then rotated 90 CW',
              8 => 'Rotated 90 CCW'}),
    0x0115 => TagEntry.new('SamplesPerPixel'),
    0x0116 => TagEntry.new('RowsPerStrip'),
    0x0117 => TagEntry.new('StripByteCounts'),
    0x011A => TagEntry.new('XResolution'),
    0x011B => TagEntry.new('YResolution'),
    0x011C => TagEntry.new('PlanarConfiguration'),
    0x011D => TagEntry.new('PageName', self.method(:ascii_bytes_to_filtered_string)),
    0x0128 => TagEntry.new('ResolutionUnit',
             { 1 => 'Not Absolute',
               2 => 'Pixels/Inch',
               3 => 'Pixels/Centimeter' }),
    0x012D => TagEntry.new('TransferFunction'),
    0x0131 => TagEntry.new('Software'),
    0x0132 => TagEntry.new('DateTime'),
    0x013B => TagEntry.new('Artist'),
    0x013E => TagEntry.new('WhitePoint'),
    0x013F => TagEntry.new('PrimaryChromaticities'),
    0x0156 => TagEntry.new('TransferRange'),
    0x0200 => TagEntry.new('JPEGProc'),
    0x0201 => TagEntry.new('JPEGInterchangeFormat'),
    0x0202 => TagEntry.new('JPEGInterchangeFormatLength'),
    0x0211 => TagEntry.new('YCbCrCoefficients'),
    0x0212 => TagEntry.new('YCbCrSubSampling'),
    0x0213 => TagEntry.new('YCbCrPositioning',
             {1 => 'Centered',
              2 => 'Co-sited'}),
    0x0214 => TagEntry.new('ReferenceBlackWhite'),
    
    0x4746 => TagEntry.new('Rating'),
    
    0x828D => TagEntry.new('CFARepeatPatternDim'),
    0x828E => TagEntry.new('CFAPattern'),
    0x828F => TagEntry.new('BatteryLevel'),
    0x8298 => TagEntry.new('Copyright'),
    0x829A => TagEntry.new('ExposureTime'),
    0x829D => TagEntry.new('FNumber'),
    0x83BB => TagEntry.new('IPTC/NAA'),
    0x8769 => TagEntry.new('ExifOffset'),
    0x8773 => TagEntry.new('InterColorProfile'),
    0x8822 => TagEntry.new('ExposureProgram',
             {0 => 'Unidentified',
              1 => 'Manual',
              2 => 'Program Normal',
              3 => 'Aperture Priority',
              4 => 'Shutter Priority',
              5 => 'Program Creative',
              6 => 'Program Action',
              7 => 'Portrait Mode',
              8 => 'Landscape Mode'}),
    0x8824 => TagEntry.new('SpectralSensitivity'),
    0x8825 => TagEntry.new('GPSInfo'),
    0x8827 => TagEntry.new('ISOSpeedRatings'),
    0x8828 => TagEntry.new('OECF'),
    0x9000 => TagEntry.new('ExifVersion', self.method(:ascii_bytes_to_filtered_string)),
    0x9003 => TagEntry.new('DateTimeOriginal'),
    0x9004 => TagEntry.new('DateTimeDigitized'),
    0x9101 => TagEntry.new('ComponentsConfiguration',
             {0 => '',
              1 => 'Y',
              2 => 'Cb',
              3 => 'Cr',
              4 => 'Red',
              5 => 'Green',
              6 => 'Blue'}),
    0x9102 => TagEntry.new('CompressedBitsPerPixel'),
    0x9201 => TagEntry.new('ShutterSpeedValue'),
    0x9202 => TagEntry.new('ApertureValue'),
    0x9203 => TagEntry.new('BrightnessValue'),
    0x9204 => TagEntry.new('ExposureBiasValue'),
    0x9205 => TagEntry.new('MaxApertureValue'),
    0x9206 => TagEntry.new('SubjectDistance'),
    0x9207 => TagEntry.new('MeteringMode',
             {0 => 'Unidentified',
              1 => 'Average',
              2 => 'CenterWeightedAverage',
              3 => 'Spot',
              4 => 'MultiSpot',
              5 => 'Pattern'}),
    0x9208 => TagEntry.new('LightSource',
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
    0x9209 => TagEntry.new('Flash',
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
    0x920A => TagEntry.new('FocalLength'),
    0x9214 => TagEntry.new('SubjectArea'),
    0x927C => TagEntry.new('MakerNote'),
    0x9286 => TagEntry.new('UserComment', self.method(:filter_encoded_string)),
    0x9290 => TagEntry.new('SubSecTime'),
    0x9291 => TagEntry.new('SubSecTimeOriginal'),
    0x9292 => TagEntry.new('SubSecTimeDigitized'),
    
    # used by Windows Explorer
    0x9C9B => TagEntry.new('XPTitle'),
    0x9C9C => TagEntry.new('XPComment'),
    0x9C9D => TagEntry.new('XPAuthor'), #(ignored by Windows Explorer if Artist exists)
    0x9C9E => TagEntry.new('XPKeywords'),
    0x9C9F => TagEntry.new('XPSubject'),

    0xA000 => TagEntry.new('FlashPixVersion', self.method(:ascii_bytes_to_filtered_string)),
    0xA001 => TagEntry.new('ColorSpace',
             {1 => 'sRGB',
              2 => 'Adobe RGB',
              65535 => 'Uncalibrated'}),
    0xA002 => TagEntry.new('ExifImageWidth'),
    0xA003 => TagEntry.new('ExifImageLength'),
    0xA005 => TagEntry.new('InteroperabilityOffset'),
    0xA20B => TagEntry.new('FlashEnergy'),               # 0x920B in TIFF/EP
    0xA20C => TagEntry.new('SpatialFrequencyResponse'),  # 0x920C
    0xA20E => TagEntry.new('FocalPlaneXResolution'),     # 0x920E
    0xA20F => TagEntry.new('FocalPlaneYResolution'),     # 0x920F
    0xA210 => TagEntry.new('FocalPlaneResolutionUnit'),  # 0x9210
    0xA214 => TagEntry.new('SubjectLocation'),           # 0x9214
    0xA215 => TagEntry.new('ExposureIndex'),             # 0x9215
    0xA217 => TagEntry.new('SensingMethod',                # 0x9217
             {1 => 'Not defined',
              2 => 'One-chip color area',
              3 => 'Two-chip color area',
              4 => 'Three-chip color area',
              5 => 'Color sequential area',
              7 => 'Trilinear',
              8 => 'Color sequential linear'}),             
    0xA300 => TagEntry.new('FileSource',
             {1 => 'Film Scanner',
              2 => 'Reflection Print Scanner',
              3 => 'Digital Camera'}),
    0xA301 => TagEntry.new('SceneType',
             {1 => 'Directly Photographed'}),
    0xA302 => TagEntry.new('CVAPattern'),
    0xA401 => TagEntry.new('CustomRendered',
             {0 => 'Normal',
              1 => 'Custom'}),
    0xA402 => TagEntry.new('ExposureMode',
             {0 => 'Auto Exposure',
              1 => 'Manual Exposure',
              2 => 'Auto Bracket'}),
    0xA403 => TagEntry.new('WhiteBalance',
             {0 => 'Auto',
              1 => 'Manual'}),
    0xA404 => TagEntry.new('DigitalZoomRatio'),
    0xA405 => TagEntry.new('FocalLengthIn35mmFilm'),
    0xA406 => TagEntry.new('SceneCaptureType',
             {0 => 'Standard',
              1 => 'Landscape',
              2 => 'Portrait',
              3 => 'Night)'}),
    0xA407 => TagEntry.new('GainControl',
             {0 => 'None',
              1 => 'Low gain up',
              2 => 'High gain up',
              3 => 'Low gain down',
              4 => 'High gain down'}),
    0xA408 => TagEntry.new('Contrast',
             {0 => 'Normal',
              1 => 'Soft',
              2 => 'Hard'}),
    0xA409 => TagEntry.new('Saturation',
             {0 => 'Normal',
              1 => 'Soft',
              2 => 'Hard'}),
    0xA40A => TagEntry.new('Sharpness',
             {0 => 'Normal',
              1 => 'Soft',
              2 => 'Hard'}),
    0xA40B => TagEntry.new('DeviceSettingDescription'),
    0xA40C => TagEntry.new('SubjectDistanceRange'),
    0xA500 => TagEntry.new('Gamma'),
    0xC4A5 => TagEntry.new('PrintIM'),
    0xEA1C =>	TagEntry.new('Padding')
    }

# interoperability tags
INTR_TAGS = {
    0x0001 => TagEntry.new('InteroperabilityIndex'),
    0x0002 => TagEntry.new('InteroperabilityVersion'),
    0x1000 => TagEntry.new('RelatedImageFileFormat'),
    0x1001 => TagEntry.new('RelatedImageWidth'),
    0x1002 => TagEntry.new('RelatedImageLength')
    }

# Ignore these tags when quick processing
# 0x927C is MakerNote Tags
# 0x9286 is user comment
IGNORE_TAGS = [0x9286, 0x927C]


MAKERNOTE_OLYMPUS_TAGS = {
    # ah HAH! those sneeeeeaky bastids! this is how they get past the fact
    # that a JPEG thumbnail is not allowed in an uncompressed TIFF file
    0x0100 => TagEntry.new('JPEGThumbnail'),
    0x0200 => TagEntry.new('SpecialMode', self.method(:olympus_special_mode)),
    0x0201 => TagEntry.new('JPEGQual',
             {1 => 'SQ',
              2 => 'HQ',
              3 => 'SHQ'}),
    0x0202 => TagEntry.new('Macro',
             {0 => 'Normal',
             1 => 'Macro',
             2 => 'SuperMacro'}),
    0x0203 => TagEntry.new('BWMode',
             {0 => 'Off',
             1 => 'On'}),
    0x0204 => TagEntry.new('DigitalZoom'),
    0x0205 => TagEntry.new('FocalPlaneDiagonal'),
    0x0206 => TagEntry.new('LensDistortionParams'),
    0x0207 => TagEntry.new('SoftwareRelease'),
    0x0208 => TagEntry.new('PictureInfo'),
    0x0209 => TagEntry.new('CameraID', self.method(:ascii_bytes_to_filtered_string)), # print as string
    0x0F00 => TagEntry.new('DataDump'),
    0x0300 => TagEntry.new('PreCaptureFrames'),
    0x0404 => TagEntry.new('SerialNumber'),
    0x1000 => TagEntry.new('ShutterSpeedValue'),
    0x1001 => TagEntry.new('ISOValue'),
    0x1002 => TagEntry.new('ApertureValue'),
    0x1003 => TagEntry.new('BrightnessValue'),
    0x1004 => TagEntry.new('FlashMode'),
    0x1004 => TagEntry.new('FlashMode',
       {2 => 'On',
        3 => 'Off'}),
    0x1005 => TagEntry.new('FlashDevice',
       {0 => 'None',
        1 => 'Internal',
        4 => 'External',
        5 => 'Internal + External'}),
    0x1006 => TagEntry.new('ExposureCompensation'),
    0x1007 => TagEntry.new('SensorTemperature'),
    0x1008 => TagEntry.new('LensTemperature'),
    0x100b => TagEntry.new('FocusMode',
       {0 => 'Auto',
        1 => 'Manual'}),
    0x1017 => TagEntry.new('RedBalance'),
    0x1018 => TagEntry.new('BlueBalance'),
    0x101a => TagEntry.new('SerialNumber'),
    0x1023 => TagEntry.new('FlashExposureComp'),
    0x1026 => TagEntry.new('ExternalFlashBounce',
       {0 => 'No',
        1 => 'Yes'}),
    0x1027 => TagEntry.new('ExternalFlashZoom'),
    0x1028 => TagEntry.new('ExternalFlashMode'),
    0x1029 => TagEntry.new('Contrast 	int16u',
       {0 => 'High',
        1 => 'Normal',
        2 => 'Low'}),
    0x102a => TagEntry.new('SharpnessFactor'),
    0x102b => TagEntry.new('ColorControl'),
    0x102c => TagEntry.new('ValidBits'),
    0x102d => TagEntry.new('CoringFilter'),
    0x102e => TagEntry.new('OlympusImageWidth'),
    0x102f => TagEntry.new('OlympusImageHeight'),
    0x1034 => TagEntry.new('CompressionRatio'),
    0x1035 => TagEntry.new('PreviewImageValid',
       {0 => 'No',
        1 => 'Yes'}),
    0x1036 => TagEntry.new('PreviewImageStart'),
    0x1037 => TagEntry.new('PreviewImageLength'),
    0x1039 => TagEntry.new('CCDScanMode',
       {0 => 'Interlaced',
        1 => 'Progressive'}),
    0x103a => TagEntry.new('NoiseReduction',
       {0 => 'Off',
        1 => 'On'}),
    0x103b => TagEntry.new('InfinityLensStep'),
    0x103c => TagEntry.new('NearLensStep'),

    # TODO - these need extra definitions
    # http =>//search.cpan.org/src/EXIFTOOL/Image-ExifTool-6.90/html/TagNames/Olympus.html
    0x2010 => TagEntry.new('Equipment'),
    0x2020 => TagEntry.new('CameraSettings'),
    0x2030 => TagEntry.new('RawDevelopment'),
    0x2040 => TagEntry.new('ImageProcessing'),
    0x2050 => TagEntry.new('FocusInfo'),
    0x3000 => TagEntry.new('RawInfo '),
    }

# 0x2020 CameraSettings
MAKERNOTE_OLYMPUS_TAG_0x2020={
    0x0100 => TagEntry.new('PreviewImageValid',
             {0 => 'No',
              1 => 'Yes'}),
    0x0101 => TagEntry.new('PreviewImageStart'),
    0x0102 => TagEntry.new('PreviewImageLength'),
    0x0200 => TagEntry.new('ExposureMode',
             {1 => 'Manual',
              2 => 'Program',
              3 => 'Aperture-priority AE',
              4 => 'Shutter speed priority AE',
              5 => 'Program-shift'}),
    0x0201 => TagEntry.new('AELock',
             {0 => 'Off',
              1 => 'On'}),
    0x0202 => TagEntry.new('MeteringMode',
             {2 => 'Center Weighted',
              3 => 'Spot',
              5 => 'ESP',
              261 => 'Pattern+AF',
              515 => 'Spot+Highlight control',
              1027 => 'Spot+Shadow control'}),
    0x0300 => TagEntry.new('MacroMode',
             {0 => 'Off',
              1 => 'On'}),
    0x0301 => TagEntry.new('FocusMode',
             {0 => 'Single AF',
              1 => 'Sequential shooting AF',
              2 => 'Continuous AF',
              3 => 'Multi AF',
              10 => 'MF'}),
    0x0302 => TagEntry.new('FocusProcess',
             {0 => 'AF Not Used',
              1 => 'AF Used'}),
    0x0303 => TagEntry.new('AFSearch',
             {0 => 'Not Ready',
              1 => 'Ready'}),
    0x0304 => TagEntry.new('AFAreas'),
    0x0401 => TagEntry.new('FlashExposureCompensation'),
    0x0500 => TagEntry.new('WhiteBalance2',
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
    0x0501 => TagEntry.new('WhiteBalanceTemperature'),
    0x0502 => TagEntry.new('WhiteBalanceBracket'),
    0x0503 => TagEntry.new('CustomSaturation'), # (3 numbers => 1. CS Value, 2. Min, 3. Max)
    0x0504 => TagEntry.new('ModifiedSaturation',
             {0 => 'Off',
              1 => 'CM1 (Red Enhance)',
              2 => 'CM2 (Green Enhance)',
              3 => 'CM3 (Blue Enhance)',
              4 => 'CM4 (Skin Tones)'}),
    0x0505 => TagEntry.new('ContrastSetting'), # (3 numbers => 1. Contrast, 2. Min, 3. Max)
    0x0506 => TagEntry.new('SharpnessSetting'), # (3 numbers => 1. Sharpness, 2. Min, 3. Max)
    0x0507 => TagEntry.new('ColorSpace',
             {0 => 'sRGB',
              1 => 'Adobe RGB',
              2 => 'Pro Photo RGB'}),
    0x0509 => TagEntry.new('SceneMode',
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
    0x050a => TagEntry.new('NoiseReduction',
             {0 => 'Off',
              1 => 'Noise Reduction',
              2 => 'Noise Filter',
              3 => 'Noise Reduction + Noise Filter',
              4 => 'Noise Filter (ISO Boost)',
              5 => 'Noise Reduction + Noise Filter (ISO Boost)'}),
    0x050b => TagEntry.new('DistortionCorrection',
             {0 => 'Off',
              1 => 'On'}),
    0x050c => TagEntry.new('ShadingCompensation',
             {0 => 'Off',
              1 => 'On'}),
    0x050d => TagEntry.new('CompressionFactor'),
    0x050f => TagEntry.new('Gradation',
             {'-1 -1 1' => 'Low Key',
              '0 -1 1' => 'Normal',
              '1 -1 1' => 'High Key'}),
    0x0520 => TagEntry.new('PictureMode',
             {1 => 'Vivid',
              2 => 'Natural',
              3 => 'Muted',
              256 => 'Monotone',
              512 => 'Sepia'}),
    0x0521 => TagEntry.new('PictureModeSaturation'),
    0x0522 => TagEntry.new('PictureModeHue?'),
    0x0523 => TagEntry.new('PictureModeContrast'),
    0x0524 => TagEntry.new('PictureModeSharpness'),
    0x0525 => TagEntry.new('PictureModeBWFilter',
             {0 => 'n/a',
              1 => 'Neutral',
              2 => 'Yellow',
              3 => 'Orange',
              4 => 'Red',
              5 => 'Green'}),
    0x0526 => TagEntry.new('PictureModeTone',
             {0 => 'n/a',
              1 => 'Neutral',
              2 => 'Sepia',
              3 => 'Blue',
              4 => 'Purple',
              5 => 'Green'}),
    0x0600 => TagEntry.new('Sequence'), # 2 or 3 numbers => 1. Mode, 2. Shot number, 3. Mode bits
    0x0601 => TagEntry.new('PanoramaMode'), # (2 numbers => 1. Mode, 2. Shot number)
    0x0603 => TagEntry.new('ImageQuality2',
             {1 => 'SQ',
              2 => 'HQ',
              3 => 'SHQ',
              4 => 'RAW'}),
    0x0901 => TagEntry.new('ManometerReading')
    }


MAKERNOTE_CASIO_TAGS={
    0x0001 => TagEntry.new('RecordingMode',
             {1 => 'Single Shutter',
              2 => 'Panorama',
              3 => 'Night Scene',
              4 => 'Portrait',
              5 => 'Landscape'}),
    0x0002 => TagEntry.new('Quality',
             {1 => 'Economy',
              2 => 'Normal',
              3 => 'Fine'}),
    0x0003 => TagEntry.new('FocusingMode',
             {2 => 'Macro',
              3 => 'Auto Focus',
              4 => 'Manual Focus',
              5 => 'Infinity'}),
    0x0004 => TagEntry.new('FlashMode',
             {1 => 'Auto',
              2 => 'On',
              3 => 'Off',
              4 => 'Red Eye Reduction'}),
    0x0005 => TagEntry.new('FlashIntensity',
             {11 => 'Weak',
              13 => 'Normal',
              15 => 'Strong'}),
    0x0006 => TagEntry.new('Object Distance'),
    0x0007 => TagEntry.new('WhiteBalance',
             {1 => 'Auto',
              2 => 'Tungsten',
              3 => 'Daylight',
              4 => 'Fluorescent',
              5 => 'Shade',
              129 => 'Manual'}),
    0x000B => TagEntry.new('Sharpness',
             {0 => 'Normal',
              1 => 'Soft',
              2 => 'Hard'}),
    0x000C => TagEntry.new('Contrast',
             {0 => 'Normal',
              1 => 'Low',
              2 => 'High'}),
    0x000D => TagEntry.new('Saturation',
             {0 => 'Normal',
              1 => 'Low',
              2 => 'High'}),
    0x0014 => TagEntry.new('CCDSpeed',
             {64 => 'Normal',
              80 => 'Normal',
              100 => 'High',
              125 => '+1.0',
              244 => '+3.0',
              250 => '+2.0'})
    }

MAKERNOTE_FUJIFILM_TAGS={
    0x0000 => TagEntry.new('NoteVersion', self.method(:ascii_bytes_to_filtered_string)),
    0x1000 => TagEntry.new('Quality'),
    0x1001 => TagEntry.new('Sharpness',
             {1 => 'Soft',
              2 => 'Soft',
              3 => 'Normal',
              4 => 'Hard',
              5 => 'Hard'}),
    0x1002 => TagEntry.new('WhiteBalance',
             {0 => 'Auto',
              256 => 'Daylight',
              512 => 'Cloudy',
              768 => 'DaylightColor-Fluorescent',
              769 => 'DaywhiteColor-Fluorescent',
              770 => 'White-Fluorescent',
              1024 => 'Incandescent',
              3840 => 'Custom'}),
    0x1003 => TagEntry.new('Color',
             {0 => 'Normal',
              256 => 'High',
              512 => 'Low'}),
    0x1004 => TagEntry.new('Tone',
             {0 => 'Normal',
              256 => 'High',
              512 => 'Low'}),
    0x1010 => TagEntry.new('FlashMode',
             {0 => 'Auto',
              1 => 'On',
              2 => 'Off',
              3 => 'Red Eye Reduction'}),
    0x1011 => TagEntry.new('FlashStrength'),
    0x1020 => TagEntry.new('Macro',
             {0 => 'Off',
              1 => 'On'}),
    0x1021 => TagEntry.new('FocusMode',
             {0 => 'Auto',
              1 => 'Manual'}),
    0x1030 => TagEntry.new('SlowSync',
             {0 => 'Off',
              1 => 'On'}),
    0x1031 => TagEntry.new('PictureMode',
             {0 => 'Auto',
              1 => 'Portrait',
              2 => 'Landscape',
              4 => 'Sports',
              5 => 'Night',
              6 => 'Program AE',
              256 => 'Aperture Priority AE',
              512 => 'Shutter Priority AE',
              768 => 'Manual Exposure'}),
    0x1100 => TagEntry.new('MotorOrBracket',
             {0 => 'Off',
              1 => 'On'}),
    0x1300 => TagEntry.new('BlurWarning',
             {0 => 'Off',
              1 => 'On'}),
    0x1301 => TagEntry.new('FocusWarning',
             {0 => 'Off',
              1 => 'On'}),
    0x1302 => TagEntry.new('AEWarning',
             {0 => 'Off',
              1 => 'On'})
    }

MAKERNOTE_CANON_TAGS = {
    0x0006 => TagEntry.new('ImageType'),
    0x0007 => TagEntry.new('FirmwareVersion'),
    0x0008 => TagEntry.new('ImageNumber'),
    0x0009 => TagEntry.new('OwnerName')
    }

# this is in element offset, name, optional value dictionary format
MAKERNOTE_CANON_TAG_0x001 = {
    1 => TagEntry.new('Macromode',
        {1 => 'Macro',
         2 => 'Normal'}),
    2 => TagEntry.new('SelfTimer'),
    3 => TagEntry.new('Quality',
        {2 => 'Normal',
         3 => 'Fine',
         5 => 'Superfine'}),
    4 => TagEntry.new('FlashMode',
        {0 => 'Flash Not Fired',
         1 => 'Auto',
         2 => 'On',
         3 => 'Red-Eye Reduction',
         4 => 'Slow Synchro',
         5 => 'Auto + Red-Eye Reduction',
         6 => 'On + Red-Eye Reduction',
         16 => 'external flash'}),
    5 => TagEntry.new('ContinuousDriveMode',
        {0 => 'Single Or Timer',
         1 => 'Continuous'}),
    7 => TagEntry.new('FocusMode',
        {0 => 'One-Shot',
         1 => 'AI Servo',
         2 => 'AI Focus',
         3 => 'MF',
         4 => 'Single',
         5 => 'Continuous',
         6 => 'MF'}),
    10 => TagEntry.new('ImageSize',
         {0 => 'Large',
          1 => 'Medium',
          2 => 'Small'}),
    11 => TagEntry.new('EasyShootingMode',
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
    12 => TagEntry.new('DigitalZoom',
         {0 => 'None',
          1 => '2x',
          2 => '4x'}),
    13 => TagEntry.new('Contrast',
         {0xFFFF => 'Low',
          0 => 'Normal',
          1 => 'High'}),
    14 => TagEntry.new('Saturation',
         {0xFFFF => 'Low',
          0 => 'Normal',
          1 => 'High'}),
    15 => TagEntry.new('Sharpness',
         {0xFFFF => 'Low',
          0 => 'Normal',
          1 => 'High'}),
    16 => TagEntry.new('ISO',
         {0 => 'See ISOSpeedRatings Tag',
          15 => 'Auto',
          16 => '50',
          17 => '100',
          18 => '200',
          19 => '400'}),
    17 => TagEntry.new('MeteringMode',
         {3 => 'Evaluative',
          4 => 'Partial',
          5 => 'Center-weighted'}),
    18 => TagEntry.new('FocusType',
         {0 => 'Manual',
          1 => 'Auto',
          3 => 'Close-Up (Macro)',
          8 => 'Locked (Pan Mode)'}),
    19 => TagEntry.new('AFPointSelected',
         {0x3000 => 'None (MF)',
          0x3001 => 'Auto-Selected',
          0x3002 => 'Right',
          0x3003 => 'Center',
          0x3004 => 'Left'}),
    20 => TagEntry.new('ExposureMode',
         {0 => 'Easy Shooting',
          1 => 'Program',
          2 => 'Tv-priority',
          3 => 'Av-priority',
          4 => 'Manual',
          5 => 'A-DEP'}),
    23 => TagEntry.new('LongFocalLengthOfLensInFocalUnits'),
    24 => TagEntry.new('ShortFocalLengthOfLensInFocalUnits'),
    25 => TagEntry.new('FocalUnitsPerMM'),
    28 => TagEntry.new('FlashActivity',
         {0 => 'Did Not Fire',
          1 => 'Fired'}),
    29 => TagEntry.new('FlashDetails',
         {14 => 'External E-TTL',
          13 => 'Internal Flash',
          11 => 'FP Sync Used',
          7 => '2nd("Rear")-Curtain Sync Used',
          4 => 'FP Sync Enabled'}),
    32 => TagEntry.new('FocusMode',
         {0 => 'Single',
          1 => 'Continuous'})
    }

MAKERNOTE_CANON_TAG_0x004 = {
    7 => TagEntry.new('WhiteBalance',
        {0 => 'Auto',
         1 => 'Sunny',
         2 => 'Cloudy',
         3 => 'Tungsten',
         4 => 'Fluorescent',
         5 => 'Flash',
         6 => 'Custom'}),
    9 => TagEntry.new('SequenceNumber'),
    14 => TagEntry.new('AFPointUsed'),
    15 => TagEntry.new('FlashBias',
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
    19 => TagEntry.new('SubjectDistance')
    }

# Nikon E99x MakerNote Tags
MAKERNOTE_NIKON_NEWER_TAGS={
    0x0001 => TagEntry.new('MakernoteVersion', self.method(:ascii_bytes_to_filtered_string)),	# Sometimes binary
    0x0002 => TagEntry.new('ISOSetting', self.method(:ascii_bytes_to_filtered_string)),
    0x0003 => TagEntry.new('ColorMode'),
    0x0004 => TagEntry.new('Quality'),
    0x0005 => TagEntry.new('Whitebalance'),
    0x0006 => TagEntry.new('ImageSharpening'),
    0x0007 => TagEntry.new('FocusMode'),
    0x0008 => TagEntry.new('FlashSetting'),
    0x0009 => TagEntry.new('AutoFlashMode'),
    0x000B => TagEntry.new('WhiteBalanceBias'),
    0x000C => TagEntry.new('WhiteBalanceRBCoeff'),
    0x000D => TagEntry.new('ProgramShift', self.method(:nikon_ev_bias)),
    # Nearly the same as the other EV vals, but step size is 1/12 EV (?)
    0x000E => TagEntry.new('ExposureDifference', self.method(:nikon_ev_bias)),
    0x000F => TagEntry.new('ISOSelection'),
    0x0011 => TagEntry.new('NikonPreview'),
    0x0012 => TagEntry.new('FlashCompensation', self.method(:nikon_ev_bias)),
    0x0013 => TagEntry.new('ISOSpeedRequested'),
    0x0016 => TagEntry.new('PhotoCornerCoordinates'),
    0x0018 => TagEntry.new('FlashBracketCompensationApplied', self.method(:nikon_ev_bias)),
    0x0019 => TagEntry.new('AEBracketCompensationApplied'),
    0x001A => TagEntry.new('ImageProcessing'),
    0x001B => TagEntry.new('CropHiSpeed'),
    0x001D => TagEntry.new('SerialNumber'),	# Conflict with 0x00A0 ?
    0x001E => TagEntry.new('ColorSpace'),
    0x001F => TagEntry.new('VRInfo'),
    0x0020 => TagEntry.new('ImageAuthentication'),
    0x0022 => TagEntry.new('ActiveDLighting'),
    0x0023 => TagEntry.new('PictureControl'),
    0x0024 => TagEntry.new('WorldTime'),
    0x0025 => TagEntry.new('ISOInfo'),
    0x0080 => TagEntry.new('ImageAdjustment'),
    0x0081 => TagEntry.new('ToneCompensation'),
    0x0082 => TagEntry.new('AuxiliaryLens'),
    0x0083 => TagEntry.new('LensType'),
    0x0084 => TagEntry.new('LensMinMaxFocalMaxAperture'),
    0x0085 => TagEntry.new('ManualFocusDistance'),
    0x0086 => TagEntry.new('DigitalZoomFactor'),
    0x0087 => TagEntry.new('FlashMode',
             {0x00 => 'Did Not Fire',
              0x01 => 'Fired, Manual',
              0x07 => 'Fired, External',
              0x08 => 'Fired, Commander Mode ',
              0x09 => 'Fired, TTL Mode'}),
    0x0088 => TagEntry.new('AFFocusPosition',
             {0x0000 => 'Center',
              0x0100 => 'Top',
              0x0200 => 'Bottom',
              0x0300 => 'Left',
              0x0400 => 'Right'}),
    0x0089 => TagEntry.new('BracketingMode',
             {0x00 => 'Single frame, no bracketing',
              0x01 => 'Continuous, no bracketing',
              0x02 => 'Timer, no bracketing',
              0x10 => 'Single frame, exposure bracketing',
              0x11 => 'Continuous, exposure bracketing',
              0x12 => 'Timer, exposure bracketing',
              0x40 => 'Single frame, white balance bracketing',
              0x41 => 'Continuous, white balance bracketing',
              0x42 => 'Timer, white balance bracketing'}),
    0x008A => TagEntry.new('AutoBracketRelease'),
    0x008B => TagEntry.new('LensFStops'),
    0x008C => TagEntry.new('NEFCurve1'),	# ExifTool calls this 'ContrastCurve'
    0x008D => TagEntry.new('ColorMode'),
    0x008F => TagEntry.new('SceneMode'),
    0x0090 => TagEntry.new('LightingType'),
    0x0091 => TagEntry.new('ShotInfo'),	# First 4 bytes are a version number in ASCII
    0x0092 => TagEntry.new('HueAdjustment'),
    # ExifTool calls this 'NEFCompression', should be 1-4
    0x0093 => TagEntry.new('Compression'),
    0x0094 => TagEntry.new('Saturation',
             {-3 => 'B&W',
              -2 => '-2',
              -1 => '-1',
              0 => '0',
              1 => '1',
              2 => '2'}),
    0x0095 => TagEntry.new('NoiseReduction'),
    0x0096 => TagEntry.new('NEFCurve2'),	# ExifTool calls this 'LinearizationTable'
    0x0097 => TagEntry.new('ColorBalance'),	# First 4 bytes are a version number in ASCII
    0x0098 => TagEntry.new('LensData'),	# First 4 bytes are a version number in ASCII
    0x0099 => TagEntry.new('RawImageCenter'),
    0x009A => TagEntry.new('SensorPixelSize'),
    0x009C => TagEntry.new('Scene Assist'),
    0x009E => TagEntry.new('RetouchHistory'),
    0x00A0 => TagEntry.new('SerialNumber'),
    0x00A2 => TagEntry.new('ImageDataSize'),
    # 00A3 => unknown - a single byte 0
    # 00A4 => In NEF, looks like a 4 byte ASCII version number ('0200')
    0x00A5 => TagEntry.new('ImageCount'),
    0x00A6 => TagEntry.new('DeletedImageCount'),
    0x00A7 => TagEntry.new('TotalShutterReleases'),
    # First 4 bytes are a version number in ASCII, with version specific
    # info to follow.  Its hard to treat it as a string due to embedded nulls.
    0x00A8 => TagEntry.new('FlashInfo'),
    0x00A9 => TagEntry.new('ImageOptimization'),
    0x00AA => TagEntry.new('Saturation'),
    0x00AB => TagEntry.new('DigitalVariProgram'),
    0x00AC => TagEntry.new('ImageStabilization'),
    0x00AD => TagEntry.new('Responsive AF'),	# 'AFResponse'
    0x00B0 => TagEntry.new('MultiExposure'),
    0x00B1 => TagEntry.new('HighISONoiseReduction'),
    0x00B7 => TagEntry.new('AFInfo'),
    0x00B8 => TagEntry.new('FileInfo'),
    # 00B9 => unknown
    0x0100 => TagEntry.new('DigitalICE'),
    0x0103 => TagEntry.new('PreviewCompression',
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
    0x0201 => TagEntry.new('PreviewImageStart'),
    0x0202 => TagEntry.new('PreviewImageLength'),
    0x0213 => TagEntry.new('PreviewYCbCrPositioning',
             {1 => 'Centered',
              2 => 'Co-sited'}), 
    0x0010 => TagEntry.new('DataDump'),
    }

MAKERNOTE_NIKON_OLDER_TAGS = {
    0x0003 => TagEntry.new('Quality',
             {1 => 'VGA Basic',
              2 => 'VGA Normal',
              3 => 'VGA Fine',
              4 => 'SXGA Basic',
              5 => 'SXGA Normal',
              6 => 'SXGA Fine'}),
    0x0004 => TagEntry.new('ColorMode',
             {1 => 'Color',
              2 => 'Monochrome'}),
    0x0005 => TagEntry.new('ImageAdjustment',
             {0 => 'Normal',
              1 => 'Bright+',
              2 => 'Bright-',
              3 => 'Contrast+',
              4 => 'Contrast-'}),
    0x0006 => TagEntry.new('CCDSpeed',
             {0 => 'ISO 80',
              2 => 'ISO 160',
              4 => 'ISO 320',
              5 => 'ISO 100'}),
    0x0007 => TagEntry.new('WhiteBalance',
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