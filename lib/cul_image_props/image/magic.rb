module Cul
module Image
module Magic
  BMP = "\x42\x4D"
  GIF = "\x47\x49\x46\x38"
  JPEG = "\xFF\xD8"
  JPEG_FRAME_MARKERS = ["\xFF\xC0","\xFF\xC1","\xFF\xC2","\xFF\xC5","\xFF\xC6","\xFF\xC9","\xFF\xCA","\xFF\xCD","\xFF\xCE"]
  JPEG_SEGMENTS = {
    "\xFF\xE0"=>"APP0",
    "\xFF\xE1"=>"APP1",
    "\xFF\xC1"=>"SOF1", # image data: extended sequential dct
    "\xFF\xC2"=>"SOF2", # image data: progressive dct
    "\xFF\xC4"=>"DHT", # image data: huffman table(s)
    "\xFF\xDA"=>"SOS", # image data: start of scan
    "\xFF\xDB"=>"DQT" # quantization tables
  }
  PNG = "\x89\x50\x4e\x47\x0d\x0a\x1a\x0a"
  TIFF_MOTOROLA_BE = "\x4d\x4d\x00\x2a"
  TIFF_INTEL_LE = "\x49\x49\x2a\x00"
end
end
end
