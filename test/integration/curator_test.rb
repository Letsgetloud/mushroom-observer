# frozen_string_literal: true

require("test_helper")

class CuratorTest < IntegrationTestCase
  def test_first_herbarium_record
    # Mary doesn't have a herbarium.
    obs = observations(:minimal_unknown_obs)
    login!("mary", "testpassword", true)
    get("/#{obs.id}")
    assert_template("observer/show_observation")
    click(label: :create_herbarium_record.t)
    assert_template("herbarium_record/create_herbarium_record")
    open_form do |form|
      form.submit("Add")
    end
    assert_template("observer/show_observation")
    assert_match(%r{href="/observer/edit_observation/#{obs.id}},
                 response.body)
  end

  def test_edit_and_remove_herbarium_record_from_show_observation
    login!("mary", "testpassword", true)
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.find { |r| r.can_edit?(mary) }
    get("/#{obs.id}")
    click(href: "/herbarium_record/edit_herbarium_record/#{rec.id}")
    assert_template("herbarium_record/edit_herbarium_record")
    open_form do |form|
      form.change("herbarium_name", "This Should Cause It to Reload Form")
      form.submit("Save")
    end
    assert_template("herbarium_record/edit_herbarium_record")
    push_page
    open_form do |form|
      form.change("herbarium_name", rec.herbarium.name)
      form.submit("Save")
    end
    assert_template("observer/show_observation")
    assert_match(%r{href="/observer/edit_observation/#{obs.id}},
                 response.body)
    go_back
    click(label: "Cancel (Show Observation)")
    assert_template("observer/show_observation")
    assert_match(%r{href="/observer/edit_observation/#{obs.id}},
                 response.body)
    click(href: "/herbarium_record/remove_observation/#{rec.id}")
    assert_template("observer/show_observation")
    assert_match(%r{href="/observer/edit_observation/#{obs.id}},
                 response.body)
    assert_not(obs.reload.herbarium_records.include?(rec))
  end

  def test_edit_herbarium_record_from_show_herbarium_record
    login!("mary", "testpassword", true)
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.find { |r| r.can_edit?(mary) }
    get("/#{obs.id}")
    click(href: "/herbarium_record/show_herbarium_record/#{rec.id}")
    assert_template("herbarium_record/show_herbarium_record")
    click(label: "Edit Fungarium Record")
    assert_template("herbarium_record/edit_herbarium_record")
    open_form do |form|
      form.change("herbarium_name", "This Should Cause It to Reload Form")
      form.submit("Save")
    end
    assert_template("herbarium_record/edit_herbarium_record")
    push_page
    click(label: "Cancel (Show Fungarium Record)")
    assert_template("herbarium_record/show_herbarium_record")
    go_back
    open_form do |form|
      form.change("herbarium_name", rec.herbarium.name)
      form.submit("Save")
    end
    assert_template("herbarium_record/show_herbarium_record")
    click(label: "Destroy Fungarium Record")
    assert_template("herbarium_record/list_herbarium_records")
    assert_not(obs.reload.herbarium_records.include?(rec))
  end

  def test_edit_herbarium_record_from_index
    login!("mary", "testpassword", true)
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.find { |r| r.can_edit?(mary) }
    get(herbarium_path(rec.herbarium.id))
    click(href: /herbarium_index/)
    assert_template("herbarium_record/list_herbarium_records")
    click(href: "/herbarium_record/edit_herbarium_record/#{rec.id}")
    assert_template("herbarium_record/edit_herbarium_record")
    open_form do |form|
      form.change("herbarium_name", "This Should Cause It to Reload Form")
      form.submit("Save")
    end
    assert_template("herbarium_record/edit_herbarium_record")
    push_page
    click(label: "Back to Fungarium Record Index")
    assert_template("herbarium_record/list_herbarium_records")
    go_back
    open_form do |form|
      form.change("herbarium_name", rec.herbarium.name)
      form.submit("Save")
    end
    assert_template("herbarium_record/list_herbarium_records")
    click(href: "/herbarium_record/destroy_herbarium_record/#{rec.id}")
    assert_template("herbarium_record/list_herbarium_records")
    assert_not(obs.reload.herbarium_records.include?(rec))
  end

  def test_herbarium_index_from_create_herbarium_record
    login!("mary", "testpassword", true)
    get("/herbarium_record/create_herbarium_record/" +
        observations(:minimal_unknown_obs).id.to_s)
    click(label: :herbarium_index.t)
    assert_template("herbaria/index")
  end

  def test_single_herbarium_search
    get("/")
    open_form("form[action*=search]") do |form|
      form.change("pattern", "New York")
      form.select("type", :HERBARIA.l)
      form.submit("Search")
    end
    assert_select(
      "#title-caption",
      { text: herbaria(:nybg_herbarium).format_name },
      "Fungaria pattern search with a single hit should land on " \
      "the show page for that Fungarium"
    )
  end

  def test_multiple_herbarium_search
    get("/")
    open_form("form[action*=search]") do |form|
      form.change("pattern", "Personal")
      form.select("type", :HERBARIA.l)
      form.submit("Search")
    end
    assert_select(
      "#title-caption",
      { text: "Fungaria Matching ‘Personal’" },
      "Fungaria pattern search with multiple hits should land on " \
      "an index page for those Fungaria"
    )
  end

  def test_herbarium_record_search
    get("/")
    open_form("form[action*=search]") do |form|
      form.change("pattern", "Coprinus comatus")
      form.select("type", :HERBARIUM_RECORDS.l)
      form.submit("Search")
    end
    assert_template("herbarium_record/list_herbarium_records")
  end

  def test_herbarium_change_code
    herbarium = herbaria(:nybg_herbarium)
    new_code = "NYBG"
    assert_not_equal(new_code, herbarium.code)
    curator = herbarium.curators[0]
    login!(curator.login, "testpassword", true)
    get(edit_herbarium_path(herbarium))
    open_form(
      # edit posts to update; this is the update url
      "form[action^='#{herbarium_path(herbarium)}']"
    ) do |form|
      form.assert_value("code", herbarium.code)
      form.change("code", new_code)
      form.submit(:SAVE.t)
    end
    assert_equal(new_code, herbarium.reload.code)
    assert_select(
      "#title-caption",
      { text: herbarium.format_name },
      "Changing Fungarium code should land on page for that Fungarium"
    )
  end

  def test_herbarium_create
    user = users(:mary)
    assert_equal([], user.curated_herbaria)
    login!(user.login, "testpassword", true)
    get(new_herbarium_path)

    open_form(
      # form POSTs to herbaria, not new_herbarium_path
      "form[action^='#{herbaria_path}']"
    ) do |form|
      form.assert_value("herbarium_name", "")
      form.assert_value("code", "")
      form.assert_value("place_name", "")
      form.assert_value("email", "")
      form.assert_value("mailing_address", "")
      form.assert_value("description", "")
      form.assert_unchecked("personal")
      form.change("herbarium_name", "Mary's Herbarium")
      form.check("personal")
      form.submit(:CREATE.t)
    end
    user = User.find(user.id)
    assert_not_empty(user.curated_herbaria)

    assert_select(
      "#title-caption",
      { text: "Mary’s Herbarium" }, # smart apostrophe
      "Creating a Fungarium should show the new Fungarium"
    )
  end

  def test_add_curators
    nybg = herbaria(:nybg_herbarium)
    # Make sure nobody broke the fixtures
    assert(nybg.curators.include?(roy),
           "Need different fixture: herbarium where roy is a curator")
    assert(nybg.curators.exclude?(mary),
           "Need different fixture: herbarium where mary is not a curator")

    # add mary as a curator
    login!(roy.login, "testpassword", true)
    get(herbarium_path(nybg))
    open_form("form[action^='#{herbaria_curators_path(id: nybg)}']") do |form|
      form.change("add_curator", mary.login)
      form.submit("Add Curator")
    end

   assert(nybg.curator?(mary),
           "Failed to add mary to curators of #{nybg.format_name}")
    # Page should have a link to delete mary as a curator
    assert_select(
      "a:match('href', ?)",
      /#{herbaria_curator_path(nybg)}\?user=#{mary.id}/,
    )
  end
end
