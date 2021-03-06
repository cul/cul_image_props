require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'nokogiri'

describe "Cul::Image::Properties" do
  
  before(:all) do
        
  end
  
  before(:each) do
    @bmp = fixture( File.join("TEST_IMAGES", "test001.bmp") )
    @png = fixture( File.join("TEST_IMAGES", "test001.png") )
    @jpg1 = fixture( File.join("TEST_IMAGES", "test001.jpg") )
    @jpg2 = fixture( File.join("TEST_IMAGES", "test002.jpg") )
    @gif = fixture( File.join("TEST_IMAGES", "test001.gif") )
    @tiff = fixture( File.join("TEST_IMAGES", "test001.tiff") )
  end
  
  after(:all) do

  end
  
  it "should automatically include the necessary modules" do
    # Cul::Image::Properties.included_modules.should include()
  end

  describe ".identify" do
    describe "bitmaps" do
      before(:each) do
        @img = fixture( File.join("TEST_IMAGES", "test001.bmp") )
        @actual = Cul::Image::Properties.identify(@img)
        @expected = Nokogiri::XML::Document.parse( fixture( File.join("TEST_PROPERTIES", "test001.bmp.xml") ) ).root.element_children
      end

      it "should identify bitmap properties" do
        compare_property_nodesets(@expected, @actual.nodeset).should == true
      end

      it "should map RDF property names to property nodes" do
        prop = @actual['http://purl.org/dc/terms/extent']
        prop.nil?.should == false
        prop.should == '174858'
      end
      
    end

    describe "png" do
      before(:each) do
        @img = fixture( File.join("TEST_IMAGES", "test001.png") )
        @actual = Cul::Image::Properties.identify(@img)
        @expected = Nokogiri::XML::Document.parse( fixture( File.join("TEST_PROPERTIES", "test001.png.xml") ) ).root.element_children
      end

      it "should identify png properties" do
        compare_property_nodesets(@expected, @actual.nodeset).should == true
      end

      it "should map RDF property names to property nodes" do
        prop = @actual['http://purl.org/dc/terms/extent']
        prop.nil?.should == false
        prop.should == '675412'
      end
    end

    describe "jpeg" do

      describe "jpeg-1" do
        before(:each) do
          @img = fixture( File.join("TEST_IMAGES", "test001.jpg") )
          @actual = Cul::Image::Properties.identify(@img)
          @expected = Nokogiri::XML::Document.parse( fixture( File.join("TEST_PROPERTIES", "test001.jpg.xml") ) ).root.element_children
        end

        it "should identify jpeg properties" do
          compare_property_nodesets(@expected, @actual.nodeset).should == true
        end

        describe "should map RDF property names to property nodes" do
          it "for extent" do
            prop = @actual['http://purl.org/dc/terms/extent']
            prop.nil?.should == false
            prop.should == '15138'
          end
          it "for length" do
            prop = @actual['http://www.w3.org/2003/12/exif/ns#imageLength']
            prop.nil?.should == false
            prop.should == '234'
          end
          it "for width" do
            prop = @actual['http://www.w3.org/2003/12/exif/ns#imageWidth']
            prop.nil?.should == false
            prop.should == '313'
          end
          it "for sampling unit" do
            prop = @actual['http://www.w3.org/2003/12/exif/ns#resolutionUnit']
            prop.nil?.should == false
            prop.should == '1'
          end
          it "for x sampling frequencies" do
            prop = @actual['http://www.w3.org/2003/12/exif/ns#xResolution']
            prop.nil?.should == false
            prop.should == '72'
          end
          it "for y sampling frequencies" do
            prop = @actual['http://www.w3.org/2003/12/exif/ns#yResolution']
            prop.nil?.should == false
            prop.should == '72'
          end
        end
      end

      describe "jpeg-2" do
        before(:each) do
          @img = fixture( File.join("TEST_IMAGES", "test002.jpg") )
          @actual = Cul::Image::Properties.identify(@img)
          @expected = Nokogiri::XML::Document.parse( fixture( File.join("TEST_PROPERTIES", "test002.jpg.xml") ) ).root.element_children
        end

        it "should identify jpeg properties" do
          compare_property_nodesets(@expected, @actual.nodeset).should == true
        end

        it "should map RDF property names to property nodes" do
          prop = @actual['http://purl.org/dc/terms/extent']
          prop.nil?.should == false
          prop.should == '389728'
        end
      end
    end

    describe "gif" do
      before(:each) do
        @img = fixture( File.join("TEST_IMAGES", "test001.gif") )
        @actual = Cul::Image::Properties.identify(@img)
        @expected = Nokogiri::XML::Document.parse( fixture( File.join("TEST_PROPERTIES", "test001.gif.xml") ) ).root.element_children
      end

      it "should identify gif properties" do
        compare_property_nodesets(@expected, @actual.nodeset).should == true
      end

      it "should map RDF property names to property nodes" do
        prop = @actual['http://purl.org/dc/terms/extent']
        prop.nil?.should == false
        prop.should == '474706'
        @actual['http://www.w3.org/2003/12/exif/ns#imageWidth'].should == '492'
        @actual['http://www.w3.org/2003/12/exif/ns#imageLength'].should == '1392'
      end
    end

    describe "tiff" do
      before(:each) do
        @img = fixture( File.join("TEST_IMAGES", "test001.tiff") )
        @actual = Cul::Image::Properties.identify(@img)
        @expected = Nokogiri::XML::Document.parse( fixture( File.join("TEST_PROPERTIES", "test001.tiff.xml") ) ).root.element_children
      end

      it "should identify all tiff properties" do
        compare_property_nodesets(@expected, @actual.nodeset).should == true
      end

      describe "should map RDF property names to property nodes" do
        it "for extent" do
          prop = @actual['http://purl.org/dc/terms/extent']
          prop.nil?.should == false
          prop.should == '5658702'
        end
        it "for length" do
          prop = @actual['http://www.w3.org/2003/12/exif/ns#imageLength']
          prop.nil?.should == false
          prop.should == '1470'
        end
        it "for width" do
          prop = @actual['http://www.w3.org/2003/12/exif/ns#imageWidth']
          prop.nil?.should == false
          prop.should == '2085'
        end
        it "for sampling unit" do
          prop = @actual['http://www.w3.org/2003/12/exif/ns#resolutionUnit']
          prop.nil?.should == false
          prop.should == '2'
        end
        it "for x sampling frequencies" do
          prop = @actual['http://www.w3.org/2003/12/exif/ns#xResolution']
          prop.nil?.should == false
          prop.should == '600'
        end
        it "for y sampling frequencies" do
          prop = @actual['http://www.w3.org/2003/12/exif/ns#yResolution']
          prop.nil?.should == false
          prop.should == '600'
        end
      end
    end

  end
end