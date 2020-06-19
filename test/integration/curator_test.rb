# frozen_string_literal: true

require "test_helper"

class CuratorTest < IntegrationTestCase
  def test_first_herbarium_record
    # Mary doesn't have a herbarium.
    obs = observations(:minimal_unknown_obs)
    login!("mary", "testpassword", true)
    get("/#{obs.id}")
    assert_template("observations/show")
    click(label: :create_herbarium_record.t)
    assert_template("herbarium_records/new")
    open_form do |form|
      form.submit("Add")
    end
    assert_template("observations/show")
    assert_match(%r{href="/observations/#{obs.id}/edit"},
                 response.body)
  end

  def test_edit_and_remove_herbarium_record_from_show_observation
    login!("mary", "testpassword", true)
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.find { |r| r.can_edit?(mary) }
    get("/#{obs.id}")
    click(href: "/herbarium_records/#{rec.id}/edit")
    assert_template("herbarium_records/edit")
    open_form do |form|
      form.change("herbarium_name", "This Should Cause It to Reload Form")
      form.submit("Save")
    end
    assert_template("herbarium_records/edit")
    push_page
    open_form do |form|
      form.change("herbarium_name", rec.herbarium.name)
      form.submit("Save")
    end
    assert_template("observations/show")
    assert_match(%r{href="/observations/#{obs.id}/edit"},
                 response.body)
    go_back
    click(label: "Cancel (Show Observation)")
    assert_template("observations/show")
    assert_match(%r{href="/observations/#{obs.id}/edit"},
                 response.body)
    click(href: "/herbarium_records/remove_observation/#{rec.id}")
    assert_template("observations/show")
    assert_match(%r{href="/observations/#{obs.id}/edit"},
                 response.body)
    assert_not(obs.reload.herbarium_records.include?(rec))
  end

  def test_edit_herbarium_record_from_show_herbarium_record
    login!("mary", "testpassword", true)
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.find { |r| r.can_edit?(mary) }
    get("/#{obs.id}")
    click(href: "/herbarium_records/#{rec.id}")
    assert_template("herbarium_records/show")
    click(label: "Edit Herbarium Record")
    assert_template("herbarium_records/edit")
    open_form do |form|
      form.change("herbarium_name", "This Should Cause It to Reload Form")
      form.submit("Save")
    end
    assert_template("herbarium_records/edit")
    push_page
    click(label: "Cancel (Show Herbarium Record)")
    assert_template("herbarium_records/show")
    go_back
    open_form do |form|
      form.change("herbarium_name", rec.herbarium.name)
      form.submit("Save")
    end
    assert_template("herbarium_records/show")
    click(label: "Destroy Herbarium Record")
    assert_template("herbarium_records/index")
    assert_not(obs.reload.herbarium_records.include?(rec))
  end

  def test_edit_herbarium_record_from_index
    login!("mary", "testpassword", true)
    obs = observations(:detailed_unknown_obs)
    rec = obs.herbarium_records.find { |r| r.can_edit?(mary) }
    get("/herbaria/#{rec.herbarium.id}")
    click(href: /herbaria/)
    assert_template("herbarium_records/index")
    click(href: "/herbarium_records/#{rec.id}/edit")
    assert_template("herbarium_records/edit")
    open_form do |form|
      form.change("herbarium_name", "This Should Cause It to Reload Form")
      form.submit("Save")
    end
    assert_template("herbarium_records/edit")
    push_page
    click(label: "Back to Herbarium Record Index")
    assert_template("herbarium_records/index")
    go_back
    open_form do |form|
      form.change("herbarium_name", rec.herbarium.name)
      form.submit("Save")
    end
    assert_template("herbarium_records/index")
    click(href: "/herbarium_records/#{rec.id}") # FIXME select text DESTROY
    assert_template("herbarium_records/index")
    assert_not(obs.reload.herbarium_records.include?(rec))
  end

  def test_herbarium_index_from_create_herbarium_record
    login!("mary", "testpassword", true)
    get("/herbarium_records/new/" +
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
    assert_template("herbaria/show")
  end

  def test_multiple_herbarium_search
    get("/")
    open_form("form[action*=search]") do |form|
      form.change("pattern", "Personal")
      form.select("type", :HERBARIA.l)
      form.submit("Search")
    end
    assert_template("herbaria/index")
  end

  def test_herbarium_record_search
    get("/")
    open_form("form[action*=search]") do |form|
      form.change("pattern", "Coprinus comatus")
      form.select("type", :HERBARIUM_RECORDS.l)
      form.submit("Search")
    end
    assert_template("herbarium_records/index")
  end

  def test_herbarium_change_code
    herbarium = herbaria(:nybg_herbarium)
    new_code = "NYBG"
    assert_not_equal(new_code, herbarium.code)
    curator = herbarium.curators[0]
    login!(curator.login, "testpassword", true)
    get("/herbaria/#{herbarium.id}/edit")
    open_form do |form|
      form.assert_value("code", herbarium.code)
      form.change("code", new_code)
      form.submit(:SAVE.t)
    end
    herbarium = Herbarium.find(herbarium.id)
    assert_equal(new_code, herbarium.code)
    assert_template("herbaria/show")
  end

  def test_herbarium_create
    user = users(:mary)
    assert_equal([], user.curated_herbaria)
    login!(user.login, "testpassword", true)
    get("/herbaria/new")
    open_form do |form|
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
    assert_template("herbaria/show")
  end
end
