require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Cul::Image::Properties::Exif" do
  
  before(:all) do
        
  end
  
  before(:each) do
  end
  
  after(:all) do

  end
  
  describe "FieldType" do
    before :all do
      FieldType = Cul::Image::Properties::Exif::FieldType
    end

    it "should assign attributes correctly" do
      obj = FieldType.new(3,"fb","foobar")
      obj.length.should == 3
      obj.abbreviation.should == "fb"
      obj.name.should == "foobar"
    end

    it "should support legacy array/bracket syntax" do
      obj = FieldType.new(3,"fb","foobar")
      obj[0].should == 3
      obj[1].should == "fb"
      obj[2].should == "foobar"
    end

  end

  describe "TagEntry" do
    before :all do
      TagEntry = Cul::Image::Properties::Exif::TagEntry
    end

    it "should translate with a block value" do
      obj = TagEntry.new("test", Proc.new {|values| "foo"})
      obj.translates?.should be_true
      obj.translate([1,2]).should == "foo"
    end

    it "should translate with a dictionary value" do
      obj = TagEntry.new("test", {1 => "foo", 2 => "bar"})
      obj.translates?.should be_true
      obj.translate([1,2]).should == "foobar"
    end

    it "should not translate when no value is given" do
      obj = TagEntry.new("test")
      obj.translates?.should be_false
    end
  end

  describe "Ratio" do
    before :all do
      Ratio = Cul::Image::Properties::Exif::Ratio
    end

    describe "class methods" do
      describe ".gcd" do
        it "should return correct greatest common denominators" do
          Ratio.gcd(1,8).should be(1)
          Ratio.gcd(8,1).should be(1)
          Ratio.gcd(24,0).should be(24)
          Ratio.gcd(0,7).should be(7)
          Ratio.gcd(24, 60).should be(12)
          Ratio.gcd(52, 39).should be(13)
        end
      end
    end
    describe "object methods" do
      describe ".reduce" do
        it "should reduce @num and @den appropriately" do
          obj = Ratio.new(3,6)
          obj.num.should == 3
          obj.den.should == 6
          obj.reduce
          obj.num.should == 1
          obj.den.should == 2
          obj = Ratio.new(3,5)
          obj.reduce
          obj.num.should == 3
          obj.den.should == 5
        end
      end

      describe ".inspect" do
        it "should reduce if possible" do
          obj = Ratio.new(3,6)
          obj.inspect.should == "1/2"
          obj = Ratio.new(3,5)
          obj.inspect.should == "3/5"
        end
      end
    end 
  end

  describe "IFD_Tag" do
    before :all do
      IFD_Tag = Cul::Image::Properties::Exif::IFD_Tag
    end

    it "should translate printables correctly when the tag entry does translation" do
      tag_values = [1,2]
      tag_entry = mock("TagEntry")
      tag_entry.stubs(:translates?).returns(true)
      tag_entry.expects(:translate).with(tag_values).returns("buckle my shoe")
      # def initialize( tag_id, field_type, tag_entry, values, field_offset, count)
      obj = IFD_Tag.new(1, 2, tag_entry, tag_values, 0, 1)
      obj.printable.should == "buckle my shoe"
    end
  end

  describe "EXIF_header" do
    before :all do
      EXIF_header = Cul::Image::Properties::Exif::EXIF_header
    end

    describe "class methods" do
      describe ".s2n_motorola" do
        it "should unpack big-endian (network byte order) strings into numbers" do
          byte = [37].pack('C*')
          short = [2,37].pack('C*')
          int = [1,128,2,37].pack('C*')
          EXIF_header.s2n_motorola(byte).should == 37
          EXIF_header.s2n_motorola(short).should == (2*256 + 37)
          EXIF_header.s2n_motorola(int).should == (1*(256**3) + 128*(256**2) + 2*256 + 37)
        end
      end
      describe ".s2n_intel" do
        it "should unpack big-endian (network byte order) strings into numbers" do
          byte = [37].pack('C*')
          short = [2,37].pack('C*')
          int = [1,128,2,37].pack('C*')
          EXIF_header.s2n_intel(byte).should == 37
          EXIF_header.s2n_intel(short).should == (37*256 + 2)
          EXIF_header.s2n_intel(int).should == (37*(256**3) + 2*(256**2) + 128*256 + 1)
        end
      end
    end
  end
end