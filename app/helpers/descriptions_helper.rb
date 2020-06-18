# frozen_string_literal: true

module DescriptionsHelper
  def is_writer?(desc)
    desc.is_writer?(@user) || in_admin_mode?
  end

  def is_admin?(desc)
    desc.is_admin?(@user) || in_admin_mode?
  end

  # Create tabs for show_description page.
  def show_description_tab_set(desc)
    # type = desc.type_tag.to_s.sub(/_description/, "").to_sym
    # admin = is_admin?(desc)
    # tabs = []
    # if true
    #   tabs << link_to(:show_object.t(type: type),
    #                   object_path(id: desc.parent_id, q: get_query_param))
    # end
    # if is_writer?(desc)
    #   tabs << link_to(:show_description_edit.t,
    #                   edit_object_path(desc.parent_id, desc.id, q: get_query_param))
    # end
    # if admin
    #   tabs << link_to(:show_description_destroy.t,
    #                   object_path(desc.parent_id, desc.id, q: get_query_param,
    #                     method: "DELETE"),
    #                   data: { confirm: :are_you_sure.l })
    # end
    # if true
    #   tabs << link_to(:show_description_clone.t,
    #                   new_object_path(desc.parent_id, clone: desc.id,
    #                     q: get_query_param),
    #                   help: :show_description_clone_help.l)
    # end
    # if admin
    #   tabs << link_to(:show_description_merge.t,
    #                   object_action_path(desc, :merge_descriptions,
    #                     q: get_query_param),
    #                   help: :show_description_merge_help.l)
    # end
    # if admin
    #   tabs << link_to(:show_description_adjust_permissions.t,
    #                   object_action_path(@description,
    #                     :adjust_permissions, q: get_query_param),
    #                   help: :show_description_adjust_permissions_help.l)
    # end
    # if desc.public && @user && (desc.parent.description_id != desc.id)
    #   tabs << link_to(:show_description_make_default.t,
    #                   object_action_path(desc,
    #                     :make_description_default, q: get_query_param),
    #                   help: :show_description_make_default_help.l)
    # end
    # if (desc.source_type == :project) &&
    #    (project = desc.source_object)
    #   tabs << link_to(:show_object.t(type: :project),
    #                   project_path(project.id))
    # end
    # if admin && (desc.source_type != :public)
    #   tabs << link_to(:show_description_publish.t,
    #                   object_action_path(desc, :publish_description,
    #                     q: get_query_param),
    #                   help: :show_description_publish_help.l)
    # end
    # tabs
  end

  # Header of the embedded description within a show_object page.
  #
  #   <%= show_embedded_description_title(desc, name) %>
  #
  #   # Renders something like this:
  #   <p>EOL Project Draft: Show | Edit | Destroy</p>
  #
  def show_embedded_description_title(desc, _parent)
    type = desc.type_tag
    title = description_title(desc)
    links = []
    if is_writer?(desc)
      links << link_to(:EDIT.t,
                       edit_object_path(desc, q: get_query_param))
    end
    if is_admin?(desc)
      links << link_to(:DESTROY.t,
                       object_path(desc, q: get_query_param, method: "DELETE"),
                       data: { confirm: :are_you_sure.l })
    end
    tag.p tag.big title + links.safe_join(" | ")
  end

  # Show list of name/location descriptions.
  def list_descriptions(obj, fake_default = false)
    type = obj.type_tag

    # Filter out empty descriptions (unless it's public or one you own).
    list = obj.descriptions.select do |desc|
      desc.has_any_notes? || (desc.user == @user) ||
        reviewer? || (desc.source_type == :public)
    end

    # Sort, putting the default one on top, followed by public ones, followed
    # by others ending in personal ones, sorting by "length" among groups.
    type_order = Description.all_source_types
    list.sort_by! do |x|
      [
        (x.id == obj.description_id ? 0 : 1),
        type_order.index(x.source_type),
        -x.note_status[0],
        -x.note_status[1],
        description_title(x),
        x.id
      ]
    end

    # Turn each into a link to show_description, and add optional controls.
    list.map! do |desc|
      any = true
      item = description_link(obj, desc, type)
      writer = is_writer?(desc)
      admin  = is_admin?(desc)
      if writer || admin
        links = []
        if writer
          links << link_to(:EDIT.t,
                           edit_object_path(desc, q: get_query_param))
        end
        if admin
          links << link_to(:DESTROY.t,
                           object_path(desc, q: get_query_param,
                             method: "DELETE"),
                           data: { confirm: :are_you_sure.l })
        end
        item += indent + "[" + links.safe_join(" | ") + "]" if links.any?
      end
      item
    end

    # Add "fake" default public description if there aren't any public ones.
    if fake_default && !obj.descriptions.any? { |d| d.source_type == :public }
      str = :description_part_title_public.t
      link = link_to(:CREATE.t, new_object_path(obj, q: get_query_param))
      str += indent + "[" + link + "]"
      list.unshift(str)
    end

    list
  end

  # Show list of alternate descriptions for show_object page.
  #
  #   <%= show_alt_descriptions(name, projects) %>
  #
  #   # Renders something like this:
  #   <p>
  #     Alternate Descriptions: Create Your Own
  #       Main Description
  #       EOL Project Draft
  #       Rolf's Draft (private)
  #   </p>
  #
  #   <p>
  #     Create New Draft For:
  #       Another Project
  #       One More Project
  #   </p>
  #
  def show_alt_descriptions(obj, projects = nil)
    type = obj.type_tag

    # Show existing drafts, with link to create new one.
    head = tag.b :show_name_descriptions.t + ": "
    head += link_to(:show_name_create_description.t,
                    new_object_path(obj, q: get_query_param))
    any = false

    # Add title and maybe "no descriptions", wrapping it all up in paragraph.
    list = list_descriptions(obj).map { |link| indent + link }
    any = list.any?
    list.unshift(head)
    list << indent + "show_#{type}_no_descriptions".to_sym.t unless any
    html = list.safe_join(safe_br)
    html = tag.p html

    # Show list of projects user is a member of.
    if projects.present?
      head2 = :show_name_create_draft.t + ": "
      list = [head2] + projects.map do |project|
        item = link_to(project.title,
                       new_object_path(obj, q: get_query_param,
                         project: project.id, source: "project"))
        indent + item
      end
      html2 = list.safe_join(safe_br)
      html += tag.p html2
    end
    html
  end

  # Create a div for notes in Description subclasses.
  #
  #   <%= colored_box(even_or_odd, html) %>
  #
  #   <% colored_box(even_or_odd) do %>
  #     Render stuff in here.  Note lack of "=" in line above.
  #   <% end %>
  #
  def colored_notes_box(even, msg = nil, &block)
    msg = capture(&block) if block_given?
    klass = [
      "ListLine#{even ? 0 : 1}",
      "mx-2",
      "p-2",
      "border-all"
    ].join(" ")
    result = tag.div msg, class: klass
    if block_given?
      concat(result)
    else
      result
    end
  end

  # Create a descriptive title for a Description.  Indicates the source and
  # very rough permissions (e.g. "public", "restricted", or "private").
  def description_title(desc)
    result = desc.partial_format_name

    # Indicate rough permissions.
    permit = if desc.parent.description_id == desc.id
               :default.l
             elsif desc.public
               :public.l
             elsif desc.is_reader?(@user) || in_admin_mode?
               :restricted.l
             else
               :private.l
             end
    result += " (#{permit})" unless /(^| )#{permit}( |$)/i.match?(result)

    t(result)
  end

  def name_section_link(title, data, query)
    if data && data != 0
      tag.p link_to(title, observations_path(q: query))
    end
  end
end
