# frozen_string_literal: true

# Custom View Helpers for Article views
#
#   xx_tabs::      List of links to display in xx tabset; include links which
#                  write Articles only if user has write permission
#   xx_title::     Title of x page; includes any markup
#
module ArticlesHelper
  def index_tabs
    return [] unless permitted?

    [link_to(:create_article_title.t, new_article_path)]
  end

  def show_tabs
    tabs = [link_to(:index_article.t, articles_path)]
    return tabs unless permitted?

    tabs.push(link_to(:create_article_title.t, new_article_path),
              link_to(:EDIT.t, edit_article_path(@article.id)),
              link_to(:DESTROY.t, action: :destroy, id: @article.id))
  end

  # "Title (#nnn)" textilized
  def show_title(article)
    capture do
      concat(article.display_title.t)
      concat(" (##{article.id || "?"})")
    end
  end

  # "Editing: Title (#nnn)"  textilized
  def edit_title(article)
    capture do
      concat("#{:EDITING.l}: ")
      concat(show_title(article))
    end
  end
end
