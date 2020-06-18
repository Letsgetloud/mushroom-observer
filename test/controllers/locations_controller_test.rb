# frozen_string_literal: true

require "test_helper"

class LocationsControllerTest < FunctionalTestCase
  def setup
    @new_pts  = 10
    @chg_pts  = 5
    @auth_pts = 50
    @edit_pts = 5
    super
  end

  # Init params based on existing location.
  def update_params_from_loc(loc)
    { id: loc.id,
      location: {
        display_name: loc.display_name,
        north: loc.north,
        west: loc.west,
        east: loc.east,
        south: loc.south,
        high: loc.high,
        low: loc.low,
        notes: loc.notes
      } }
  end

  # A location that isn't in fixtures.
  def barton_flats_params
    name = "Barton Flats, California, USA"
    {
      display_name: name,
      location: {
        display_name: name,
        north: 34.1865,
        west: -116.924,
        east: -116.88,
        south: 34.1571,
        high: 2000.0,
        low: 1600.0,
        notes: "This is now Barton Flats"
      }
    }
  end

  # Post a change that fails -- make sure no new version created.
  def location_error(page, params)
    loc_count = Location.count
    past_loc_count = Location::Version.count
    desc_count = Location::Description.count
    past_desc_count = Location::Description::Version.count
    post_requires_login(page, params)
    assert_action_partials(page.to_s, %w[_form_location _textilize_help])
    assert_equal(loc_count, Location.count)
    assert_equal(past_loc_count, Location::Version.count)
    assert_equal(desc_count, Location::Description.count)
    assert_equal(past_desc_count, Location::Description::Version.count)
  end

  # Post "create_location" with errors.
  def construct_location_error(params)
    location_error(:new, params)
  end

  # Post "update_location" with errors.
  def update_location_error(params)
    location_error(:edit, params)
  end

  ##############################################################################

  def test_location_help
    get_with_dump(:help)
  end

  def test_show_location
    location = locations(:albion)
    updated_at = location.updated_at
    log_updated_at = location.rss_log.updated_at
    get_with_dump(:show, id: location.id)
    assert_template(partial: "_location")
    assert_template(partial: "_location_description")
    assert_template(partial: "_show_comments")
    location.reload
    assert_equal(updated_at, location.updated_at)
    assert_equal(log_updated_at, location.rss_log.updated_at)
  end

  def test_show_location_admin_mode
    login("mary")
    make_admin("mary")
    location = locations(:albion)
    get_with_dump(:show, id: location.id)
  end

  def test_show_past_location
    location = locations(:albion)
    get_with_dump(:show_past_location, id: location.id,
                                       version: location.version - 1)
    assert_template("show_past_location", partial: "_location")
  end

  def test_show_past_location_no_version
    location = locations(:albion)
    get_with_dump(:show_past_location, id: location.id)
    assert_response(:redirect)
  end

  def test_list_locations
    get_with_dump(:index)
    assert_template(:index)
  end

  def test_location_advanced_search
    query = Query.lookup_and_save(:Location, :advanced_search,
                                  location: "California")
    get(:advanced_search, @controller.query_params(query))
    assert_template(:index)
  end

  def test_location_bounding_box
    delta = 0.001
    get(:index, north: 0, south: 0, east: 0, west: 0)
    query = Query.find(QueryRecord.last.id)
    assert_equal(0 + delta, query.params[:north])
    assert_equal(0 - delta, query.params[:south])
    assert_equal(0 + delta, query.params[:east])
    assert_equal(0 - delta, query.params[:west])

    get(:index, north: 90, south: -90, east: 180, west: -180)
    query = Query.find(QueryRecord.last.id)
    assert_equal(90, query.params[:north])
    assert_equal(-90, query.params[:south])
    assert_equal(180, query.params[:east])
    assert_equal(-180, query.params[:west])
  end

  def test_list_countries
    get_with_dump(:list_countries)
    assert_template("list_countries")
  end

  def test_list_by_country
    get_with_dump(:list_by_country, country: "USA")
    assert_template(:index)
  end

  def test_list_by_country_with_quote
    get_with_dump(:list_by_country, country: "Cote d'Ivoire")
    assert_template(:index)
  end

  def test_list_by_country_regexp_ok
    login("mary")

    get(:list_by_country, country: "USA")
    usa_loc_array = assigns(:objects)
    loc_usa = Location.create!(name: "Santa Fe, New Mexico, USA",
                               north: 34.1865,
                               west: -116.924,
                               east: -116.88,
                               south: 34.1571,
                               notes: "Santa Fe",
                               user: @mary)
    get(:list_by_country, country: "USA")
    assert_obj_list_equal(usa_loc_array << loc_usa, assigns(:objects), :sort)

    get(:list_by_country, country: "Mexico")
    assert_obj_list_equal([], assigns(:objects))

    loc_mex1 = Location.create!(
      name: "Somewhere, Chihuahua, Mexico",
      north: 28.7729082,
      west: -106.1671059,
      east: -105.9612896,
      south: 28.5586774,
      notes: "somewhere Mexico",
      user: @mary
    )
    loc_mex2 = Location.create!(
      name: "Oaxaca, Oaxaca, Mexico",
      north: 17.1332939,
      west: -96.7806765,
      east: -96.6907866,
      south: 17.0293023,
      notes: "somewhere else in Mexico or this test will not work",
      user: @mary
    )
    get(:list_by_country, country: "Mexico")
    assert_obj_list_equal([loc_mex1, loc_mex2], assigns(:objects), :sort)
  end

  def test_locations_by_user
    get_with_dump(:locations_by_user, id: rolf.id)
    assert_template(:index)
  end

  def test_locations_by_editor
    get_with_dump(:locations_by_editor, id: rolf.id)
    assert_template(:index)
  end

  def test_create_location
    requires_login(:new)
    assert_form_action(url: "/locations")
  end

  # This was causing a crash in live server.
  def test_construct_location_empty_form
    login("mary")
    post(:new,
         where: "",
         approved_where: "",
         location: { display_name: "" })
  end

  # Test a simple location creation.
  def test_construct_location_simple
    count = Location.count
    params = barton_flats_params
    display_name = params[:display_name]

    post_requires_login(:new, params)
    loc = assigns(:location)

    assert_redirected_to(
      controller: :locations,
      action: :show,
      id: loc.id
    )
    assert_equal(count + 1, Location.count)
    assert_equal(10 + @new_pts, rolf.reload.contribution)
    # Make sure it's the right Location
    assert_equal(display_name, loc.display_name)

    # rubocop:disable Rails/DynamicFindBy
    # find_by_name_or_reverse_name is an MO method, not a Rails finder
    loc = Location.find_by_name_or_reverse_name(display_name)
    # rubocop:enable Rails/DynamicFindBy
    assert_nil(loc.description)
    assert_not_nil(loc.rss_log)
  end

  def test_construct_location_name_errors
    # Test creating a location with a dubious location name
    params = barton_flats_params
    params[:location][:display_name] = "Somewhere Dubious"
    construct_location_error(params)
  end

  def test_construct_location_screwy_names
    login("dick")
    loc = locations(:burbank)
    params = update_params_from_loc(loc)
    params.delete(:id)

    params[:location][:display_name] = ""
    post(:new, params)
    assert_response(:success) # means failure!

    params[:location][:display_name] = " Strip  This,  Maine,  USA "
    post(:new, params)
    assert_response(:redirect)
    assert_equal("Strip This, Maine, USA", Location.last.display_name)
  end

  def test_construct_location_errors
    # Test for north > 90
    params = barton_flats_params
    params[:location][:north] = 100
    construct_location_error(params)

    # Test for south < -90
    params = barton_flats_params
    params[:location][:south] = -100
    construct_location_error(params)

    # Test for north < south
    params = barton_flats_params
    north = params[:location][:north]
    params[:location][:north] = params[:location][:south]
    params[:location][:south] = north
    construct_location_error(params)

    # Test for west < -180
    params = barton_flats_params
    params[:location][:west] = -200
    construct_location_error(params)

    # Test for west > 180
    params = barton_flats_params
    params[:location][:west] = 200
    construct_location_error(params)

    # Test for east < -180
    params = barton_flats_params
    params[:location][:east] = -200
    construct_location_error(params)

    # Test for east > 180
    params = barton_flats_params
    params[:location][:east] = 200
    construct_location_error(params)

    # Test for high < low
    params = barton_flats_params
    high = params[:location][:high]
    params[:location][:high] = params[:location][:low]
    params[:location][:low] = high
    construct_location_error(params)
  end

  def test_edit_location
    loc = locations(:albion)
    params = { id: loc.id.to_s }
    requires_login(:edit, params)
    assert_form_action(action: :edit,
                       id: loc.id.to_s,
                       approved_where: loc.display_name)
    assert_input_value(:location_display_name, loc.display_name)
  end

  def test_edit_unknown_location
    loc = locations(:unknown_location)
    old_loc_display_name = loc.display_name
    params = { id: loc.id,
               location: { display_name: "Rome, Italy" } }
    post_requires_login(:edit, params)

    assert_equal(old_loc_display_name, loc.reload.display_name,
                 "Users should not be able to change Unknown location")
  end

  def test_update_location
    count = Location::Version.count
    count2 = Location::Description::Version.count
    contrib = rolf.contribution

    # Turn Albion into Barton Flats.
    loc = locations(:albion)
    updated_at = loc.updated_at
    log_updated_at = loc.rss_log.updated_at
    old_params = update_params_from_loc(loc)
    params = barton_flats_params
    params[:location][:display_name] =
      Location.user_name(rolf, params[:location][:display_name])
    params[:id] = loc.id
    post_requires_login(:edit, params)
    assert_redirected_to(
      controller: :locations,
      action: :show,
      id: loc.id
    )
    assert_equal(contrib, rolf.reload.contribution)

    # Should have created a new version of location only.
    assert_equal(count + 1, Location::Version.count)
    assert_equal(count2, Location::Description::Version.count)

    # Should now look like Barton Flats.
    loc = Location.find(loc.id)
    new_params = update_params_from_loc(loc)
    assert_not_equal(new_params, old_params)

    # It and the RssLog should have been updated
    assert_not_equal(updated_at, loc.updated_at)
    assert_not_equal(log_updated_at, loc.rss_log.updated_at)

    # Only compare the keys that are in both.
    bfp = barton_flats_params
    key_count = 0
    bfp.each_key do |k|
      if new_params[k]
        key_count += 1
        assert_equal(new_params[k], bfp[k])
      end
    end
    assert(key_count.positive?) # Make sure something was compared.

    # Rolf was already author, Mary doesn't become editor because
    # there was no change.
    assert_user_list_equal([rolf], loc.description.authors)
    assert_user_list_equal([], loc.description.editors)
  end

  # Test update for north > 90.
  def test_update_location_errors
    params = update_params_from_loc(locations(:albion))
    params[:location][:north] = 100
    update_location_error(params)
  end

  # Test update with a dubious location name
  def test_update_location_name_errors
    params = update_params_from_loc(locations(:albion))
    params[:location][:display_name] = "Somewhere Dubious"
    update_location_error(params)
  end

  def test_update_location_screwy_names
    login("dick")
    loc = locations(:burbank)
    params = update_params_from_loc(loc)

    params[:location][:display_name] = ""
    post(:edit, params)
    assert_response(:success) # means failure!

    params[:location][:display_name] = " Strip  This,  Maine,  USA "
    post(:edit, params)
    assert_response(:redirect)
    assert_equal("Strip This, Maine, USA", loc.reload.display_name)
  end

  def test_update_location_with_scientific_names
    rolf.update(location_format: :scientific)
    rolf.reload
    login("rolf")
    loc = locations(:burbank)
    normal_name = loc.name
    scientific_name = loc.display_name
    assert_not_equal(normal_name, scientific_name)
    get(:edit, id: loc.id)
    assert_input_value(:location_display_name, scientific_name)

    new_normal_name = "Undefined Town, California, USA"
    new_scientific_name = "USA, California, Undefined Town"
    params = update_params_from_loc(loc)
    params[:location][:display_name] = new_normal_name
    post(:edit, params)
    assert_response(:success) # means failure

    params[:location][:display_name] = new_scientific_name
    post(:edit, params)
    assert_response(:redirect) # means success
    loc.reload
    assert_equal(new_normal_name, loc.name)
    assert_equal(new_scientific_name, loc.display_name)
  end

  # Burbank has observations so it stays.
  def test_update_location_user_merge
    to_go = locations(:burbank)
    to_stay = locations(:albion)
    params = update_params_from_loc(to_go)
    params[:location][:display_name] = to_stay.display_name
    loc_count = Location.count
    desc_count = Location::Description.count
    past_loc_count = Location::Version.count
    past_desc_count = Location::Description::Version.count
    post_requires_login(:edit, params)
    assert_redirected_to(
      controller: :locations,
      action: :show,
      id: to_go.id
    )
    assert_equal(loc_count - 1, Location.count)
    assert_equal(desc_count, Location::Description.count)
    assert_equal(past_loc_count - 1, Location::Version.count)
    assert_equal(past_desc_count, Location::Description::Version.count)
    assert_equal(10 - @new_pts, rolf.reload.contribution)
  end

  def test_update_location_admin_merge
    to_go = locations(:albion)
    to_stay = locations(:burbank)
    params = update_params_from_loc(to_go)
    params[:location][:display_name] = to_stay.display_name

    loc_count = Location.count
    desc_count = Location::Description.count
    past_loc_count = Location::Version.count
    past_desc_count = Location::Description::Version.count
    past_locs_to_go = to_go.versions.length
    past_descs_to_go = 0

    make_admin("rolf")
    post_with_dump(:edit, params)

    # assert_template(action: :show)
    assert_redirected_to(action: :show, id: to_stay.id)
    assert_equal(loc_count - 1, Location.count)
    assert_equal(desc_count, Location::Description.count)
    assert_equal(past_loc_count + 1 - past_locs_to_go, Location::Version.count)
    assert_equal(past_desc_count - past_descs_to_go,
                 Location::Description::Version.count)
  end

  def test_post_edit_location_locked
    location = locations(:unknown_location)
    params = {
      id: location.id,
      location: {
        locked: "",
        display_name: "My Back Yard, Fresno, California, USA",
        north: "31",
        south: "30",
        east: "-118",
        west: "-119",
        high: "30",
        low: "10",
        notes: "new notes"
      }
    }

    login("rolf")
    get(:edit, id: location.id)
    assert_select("input[type=checkbox]#location_locked", count: 0)
    assert_select("input[type=text]#location_display_name", count: 0)
    assert_select("input[type=text]#location_north", count: 0)
    assert_select("input[type=text]#location_south", count: 0)
    assert_select("input[type=text]#location_east", count: 0)
    assert_select("input[type=text]#location_west", count: 0)
    assert_select("input[type=text]#location_high", count: 0)
    assert_select("input[type=text]#location_low", count: 0)

    post(:edit, params)
    location.reload
    assert_true(location.locked)
    assert_equal("Unknown", location.name)
    assert_equal(90, location.north)
    assert_equal(-90, location.south)
    assert_equal(180, location.east)
    assert_equal(-180, location.west)
    assert_nil(location.high)
    assert_nil(location.low)
    assert_equal("new notes", location.notes)

    make_admin("mary")
    get(:edit, id: location.id)
    assert_select("input[type=checkbox]#location_locked", count: 1)
    assert_select("input[type=text]#location_display_name", count: 1)
    assert_select("input[type=text]#location_north", count: 1)
    assert_select("input[type=text]#location_south", count: 1)
    assert_select("input[type=text]#location_east", count: 1)
    assert_select("input[type=text]#location_west", count: 1)
    assert_select("input[type=text]#location_high", count: 1)
    assert_select("input[type=text]#location_low", count: 1)

    post(:edit, params)
    location.reload
    assert_false(location.locked)
    assert_equal("My Back Yard, Fresno, California, USA", location.name)
    assert_equal(31, location.north)
    assert_equal(30, location.south)
    assert_equal(-118, location.east)
    assert_equal(-119, location.west)
    assert_equal(30, location.high)
    assert_equal(10, location.low)
  end

  def test_list_merge_options
    albion = locations(:albion)

    # Full match with albion.
    requires_login(:list_merge_options, where: albion.display_name)
    assert_obj_list_equal([albion], assigns(:matches))

    # Should match against albion.
    requires_login(:list_merge_options, where: "Albion, CA")
    assert_obj_list_equal([albion], assigns(:matches))

    # Should match against albion.
    requires_login(:list_merge_options, where: "Albion Field Station, CA")
    assert_obj_list_equal([albion], assigns(:matches))

    # Shouldn't match anything.
    requires_login(:list_merge_options, where: "Somewhere out there")
    assert_nil(assigns(:matches))
  end

  def test_add_to_location
    User.current = rolf
    albion = locations(:albion)
    obs = Observation.create!(
      when: Time.zone.now,
      where: "undefined location",
      notes: "new observation"
    )
    assert_nil(obs.location)

    params = {
      where: obs.where,
      location: albion.id
    }
    requires_login(:add_to_location, params)
    assert_redirected_to(action: :index)
    assert_not_nil(obs.reload.location)
    assert_equal(albion, obs.location)
  end

  def test_add_to_location_scientific
    login("roy")
    albion = locations(:albion)
    obs = Observation.create!(
      when: Time.zone.now,
      where: (where = "Albion, Mendocino Co., California, USA"),
      notes: "new observation"
    )
    assert_nil(obs.location)
    assert_equal(:scientific, roy.location_format)
    params = {
      where: where,
      location: albion.id
    }
    requires_login(:add_to_location, params, "roy")
    assert_redirected_to(action: :index)
    assert_not_nil(obs.reload.location)
    assert_equal(albion, obs.location)
  end

  def test_map_locations
    # test_map_locations - map everything
    get_with_dump(:map_locations)
    assert_template(:map_locations)

    # test_map_locations_empty - map nothing
    get_with_dump(:map_locations, pattern: "Never Never Land")
    assert_template(:map_locations)

    # test_map_locations_some - map something
    get_with_dump(:map_locations, pattern: "California")
    assert_template(:map_locations)
  end

  def assert_show_location
    assert_template(partial: "_location")
    assert_template(partial: "_location_description")
    assert_template(partial: "_show_comments")
  end

  def test_interest_in_show_location
    # No interest in this location yet.
    albion = locations(:albion)
    login("rolf")
    get(:show, id: albion.id)
    assert_show_location
    assert_image_link_in_html(/watch\d*.png/,
                              controller: :interests,
                              action: :set_interest,
                              type: "Location",
                              id: albion.id,
                              state: 1)
    assert_image_link_in_html(/ignore\d*.png/,
                              controller: :interests,
                              action: :set_interest,
                              type: "Location",
                              id: albion.id,
                              state: -1)

    # Turn interest on and make sure there is an icon linked to delete it.
    Interest.new(target: albion,
                 user: rolf,
                 state: true).save
    get(:show, id: albion.id)
    assert_show_location
    assert_image_link_in_html(/halfopen\d*.png/,
                              controller: :interests,
                              action: :set_interest,
                              type: "Location",
                              id: albion.id,
                              state: 0)
    assert_image_link_in_html(/ignore\d*.png/,
                              controller: :interests,
                              action: :set_interest,
                              type: "Location",
                              id: albion.id,
                              state: -1)

    # Destroy that interest, create new one with interest off.
    Interest.where(user_id: rolf.id).last.destroy
    Interest.new(target: albion,
                 user: rolf,
                 state: false).save
    get(:show, id: albion.id)
    assert_show_location
    assert_image_link_in_html(/halfopen\d*.png/,
                              controller: :interests,
                              action: :set_interest,
                              type: "Location",
                              id: albion.id,
                              state: 0)
    assert_image_link_in_html(/watch\d*.png/,
                              controller: :interests,
                              action: :set_interest,
                              type: "Location",
                              id: albion.id,
                              state: 1)
  end

  def test_update_location_scientific_name
    loc = Location.first
    params = {
      id: loc.id,
      location: {}
    }

    login("rolf")
    assert_equal(:postal, rolf.location_format)
    postal_name = "Missoula, Montana, USA"
    scientific_name = "USA, Montana, Missoula"
    params[:location][:display_name] = postal_name
    post(:edit, params)
    assert_flash_success
    assert_response(:redirect)
    loc.reload
    assert_equal(postal_name, loc.name)
    assert_equal(scientific_name, loc.scientific_name)

    login("roy")
    assert_equal(:scientific, roy.location_format)
    postal_name = "Santa Fe, New Mexico, USA"
    scientific_name = "USA, New Mexico, Santa Fe"
    params[:location][:display_name] = scientific_name
    post(:edit, params)
    assert_flash_success
    assert_response(:redirect)
    loc.reload
    assert_equal(postal_name, loc.name)
    assert_equal(scientific_name, loc.scientific_name)
  end

  def named_obs_query(name)
    Query.lookup(:Observation, :pattern_search, pattern: name, by: :name)
  end

  def test_coercing_sorted_observation_query_into_location_query
    @controller.
      coerce_query_for_undefined_locations(named_obs_query("Pasadena").
      coerce(:Location))
  end
end
