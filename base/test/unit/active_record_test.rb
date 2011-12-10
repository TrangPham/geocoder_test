require 'test_helper'

class ActiveRecordTest < ActiveSupport::TestCase

  def setup
    Geocoder::Configuration.lookup = :google
    Geocoder::Configuration.cache = nil
  end

  test "associations" do
    assert_equal [venues(:beacon)], colors(:red).venues
  end

  test "use of includes doesn't raise error" do
    assert_nothing_raised do
      Venue.near([40.7, -74]).includes(:color)
    end
  end

  test "count returns an integer" do
    assert_kind_of Fixnum, Venue.near([40.7, -74]).count
  end

  test "geocoded and not geocoded scopes" do
    Venue.create(:name => "Turd Hall")
    assert_equal 6, Venue.geocoded.count
    assert_equal 1, Venue.not_geocoded.count
  end


  # --- single table inheritance ---

  test "sti child can access parent config" do
    assert_not_nil Temple.geocoder_options
  end

  test "sti child geocoding works" do
    a = Arena.new(
      :name => "Mellon Arena",
      :address => "66 Mario Lemieux Place, Pittsburgh, PA")
    a.geocode
    assert_not_nil a.latitude
  end


  # --- distance ---

  test "distance of found points" do
    leeway = sqlite? ? 2 : 1
    distance = 9
    nearbys = Venue.near(hempstead_coords, 15)
    nikon = nearbys.detect{ |v| v.id == Fixtures.identify(:nikon) }
    assert (distance - nikon.distance).abs < leeway,
      "Distance should be close to #{distance} miles but was #{nikon.distance}"
  end

  test "distance of found points in kilometers" do
    leeway = sqlite? ? 2 : 1
    distance = 14.5
    nearbys = Venue.near(hempstead_coords, 25, :units => :km)
    nikon = nearbys.detect{ |v| v.id == Fixtures.identify(:nikon) }
    assert (distance - nikon.distance).abs < leeway,
      "Distance should be close to #{distance} miles but was #{nikon.distance}"
  end


  # --- bearing ---

  test "bearing (linear) of found points" do
    leeway = sqlite? ? 45 : 2
    bearing = 137
    nearbys = Venue.near(hempstead_coords, 15, :bearing => :linear)
    nikon = nearbys.detect{ |v| v.id == Fixtures.identify(:nikon) }
    assert (bearing - nikon.bearing).abs < leeway,
      "Bearing should be close to #{bearing} degrees but was #{nikon.bearing}"
  end

  test "bearing (spherical) of found points" do
    leeway = sqlite? ? 45 : 2
    bearing = 144
    nearbys = Venue.near(hempstead_coords, 15, :bearing => :spherical)
    nikon = nearbys.detect{ |v| v.id == Fixtures.identify(:nikon) }
    assert (bearing - nikon.bearing).abs < leeway,
      "Bearing should be close to #{bearing} degrees but was #{nikon.bearing}"
  end

  test "don't calculate bearing" do
    nearbys = Venue.near(hempstead_coords, 15, :bearing => false)
    nikon = nearbys.detect{ |v| v.id == Fixtures.identify(:nikon) }
    assert_raises(NoMethodError) { nikon.bearing }
  end


  # --- near ---

  test "near finds venues near a point" do
    assert Venue.near(hempstead_coords, 15).include?(venues(:nikon))
  end

  test "near doesn't find venues not near a point" do
    assert !Venue.near(hempstead_coords, 5).include?(venues(:forum))
  end

  test "nearbys finds all venues near another venue" do
    assert venues(:nikon).nearbys(40).include?(venues(:beacon))
    assert venues(:beacon).nearbys(40).include?(venues(:nikon))
  end

  test "nearbys doesn't find venues not near another venue" do
    assert !venues(:nikon).nearbys(10).include?(venues(:forum))
    assert !venues(:forum).nearbys(10).include?(venues(:beacon))
  end

  test "nearbys doesn't include self" do
    # this also tests the :exclude option to the near method
    assert !venues(:nikon).nearbys(5).include?(venues(:nikon))
  end

  test "near method select option" do
    forum = venues(:forum)
    venues = Venue.near(hollywood_coords, 20,
      :select => "*, latitude * longitude AS junk")
    assert venues.first.junk.to_f - (forum.latitude * forum.longitude) < 0.1
  end

  test "near method units option" do
    assert_equal 2, Venue.near(hempstead_coords, 25, :units => :mi).length
    assert_equal 1, Venue.near(hempstead_coords, 25, :units => :km).length
  end

  test "near is compatible with other scopes" do
    assert_equal venues(:beacon), Venue.near(hempstead_coords, 25).limit(1).offset(1).first
  end

  test "near finds no objects near ungeocodable address" do
    assert_equal [], Venue.near("asdfasdf")
  end

  # --- distance_from ---

  test "distance_from_sql finds associations ordered by distance" do
    assert_equal Color.joins(:venues).order(Venue.distance_from_sql(venues(:riverside))), [colors(:yellow), colors(:green), colors(:black), colors(:red)]
  end

  # --- within_bounding_box ---

  test "within_bounding_box finds correct objects" do
    box = [39.0, -75.0, 41.0, -73.0]
    venues = Venue.within_bounding_box(box)
    assert venues.include?(venues(:nikon))
    assert venues.include?(venues(:beacon))
    assert !venues.include?(venues(:forum))
  end

  test "within_bounding_box finds correct objects if longitudes span 180th meridian" do
    box = [39.0, -73.7, 41.0, -117.0]
    venues = Venue.within_bounding_box(box)
    assert venues.include?(venues(:nikon))
    assert !venues.include?(venues(:beacon))
    assert venues.include?(venues(:forum))
  end

  test "within_bounding_box doesn't find any venues if params are empty" do
    assert Venue.within_bounding_box([]).empty?
  end

  test "within_bounding_box doesn't find any venues if params are nil" do
    assert Venue.within_bounding_box(nil).empty?
  end

  private # ------------------------------------------------------------------

  def sqlite?
    ActiveRecord::Base.connection.adapter_name.match(/sqlite/i)
  end

  ##
  # Coordinates of Hempstead, Long Island, NY, about 8 miles from Jones Beach.
  #
  def hempstead_coords
    [40.7062128, -73.6187397]
  end

  ##
  # Coordinates of Hollywood, CA, about 10 miles from The Great Western Forum.
  #
  def hollywood_coords
    [34.09833, -118.32583]
  end
end
