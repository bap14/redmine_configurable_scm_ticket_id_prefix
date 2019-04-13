require_dependency 'application_helper'

module RedmineConfigurableScmTicketIdPrefix
  module Patches
    module ApplicationHelperPatch
      def self.prepended(base)

        base.class_eval do
          alias_method :parse_redmine_links_without_alt_prefix, :parse_redmine_links
          alias_method :parse_redmine_links, :parse_redmine_links_with_alt_prefix
        end
      end

      def parse_redmine_links_with_alt_prefix(text, default_project, obj, attr, only_path, options)
        #-----[ BEGIN CUSTOMIZATION ]----------
        ## Prep alternate ticket id prefix
        alt_id_prefix = Setting.plugin_redmine_configurable_scm_ticket_id_prefix["ticket_id_prefix"].downcase.split(",").collect(&:strip)

        # Revert to the standard Redmine usage if no customization is provided
        if alt_id_prefix.nil? || alt_id_prefix.empty?
          alt_id_prefix_regexp = "\#\#?"
          alt_id_prefix = %w( # ## )
        else
          alt_id_prefix_regexp = alt_id_prefix.collect{|aip| Regexp.escape(aip)}.join("|")
        end
        #-----[ END CUSTOMIZATION ]----------

        links_regex =
            %r{
            <a( [^>]+?)?>(?<tag_content>.*?)</a>|
            (?<leading>[\s\(,\-\[\>]|^)
            (?<esc>!)?
            (?<project_prefix>(?<project_identifier>[a-z0-9\-_]+):)?
            (?<prefix>attachment|document|version|forum|news|message|project|commit|source|export|user)?
            (
              (
                (?<sep1>#{alt_id_prefix_regexp})|
                (
                  (?<repo_prefix>(?<repo_identifier>[a-z0-9\-_]+)\|)?
                  (?<sep2>r)
                )
              )
              (
                (?<identifier1>\d+)
                (?<comment_suffix>
                  (\#note)?
                  -(?<comment_id>\d+)
                )?
              )|
              (
              (?<sep3>:)
              (?<identifier2>[^"\s<>][^\s<>]*?|"[^"]+?")
              )|
              (
              (?<sep4>@)
              (?<identifier3>[A-Za-z0-9_\-@\.]*)
              )
            )
            (?=
              (?=[[:punct:]][^A-Za-z0-9_/])|
              ,|
              \s|
              \]|
              <|
              $)
        }x

        text.gsub!(links_regex) do |_|
          tag_content = $~[:tag_content]
          leading = $~[:leading]
          esc = $~[:esc]
          project_prefix = $~[:project_prefix]
          project_identifier = $~[:project_identifier]
          prefix = $~[:prefix]
          repo_prefix = $~[:repo_prefix]
          repo_identifier = $~[:repo_identifier]
          sep = $~[:sep1] || $~[:sep2] || $~[:sep3] || $~[:sep4]
          identifier = $~[:identifier1] || $~[:identifier2] || $~[:identifier3]
          comment_suffix = $~[:comment_suffix]
          comment_id = $~[:comment_id]

          if tag_content
            $&
          else
            link = nil
            project = default_project
            if project_identifier
              project = Project.visible.find_by_identifier(project_identifier)
            end
            if esc.nil?
              if prefix.nil? && sep == 'r'
                if project
                  repository = nil
                  if repo_identifier
                    repository = project.repositories.detect {|repo| repo.identifier == repo_identifier}
                  else
                    repository = project.repository
                  end
                  # project.changesets.visible raises an SQL error because of a double join on repositories
                  if repository &&
                      (changeset = Changeset.visible.
                          find_by_repository_id_and_revision(repository.id, identifier))
                    link = link_to(h("#{project_prefix}#{repo_prefix}r#{identifier}"),
                                   {:only_path => only_path, :controller => 'repositories',
                                    :action => 'revision', :id => project,
                                    :repository_id => repository.identifier_param,
                                    :rev => changeset.revision},
                                   :class => 'changeset',
                                   :title => truncate_single_line_raw(changeset.comments, 100))
                  end
                end
              #-----[ BEGIN CUSTOMIZATION ]----------
              elsif !alt_id_prefix.index(sep).nil?
              #-----[ END CUSTOMIZATION ]----------
                oid = identifier.to_i
                case prefix
                when nil
                  if oid.to_s == identifier &&
                      issue = Issue.visible.find_by_id(oid)
                    anchor = comment_id ? "note-#{comment_id}" : nil
                    url = issue_url(issue, :only_path => only_path, :anchor => anchor)
                    link = if sep == '##'
                             link_to("#{issue.tracker.name} #{sep}#{oid}#{comment_suffix}",
                                     url,
                                     :class => issue.css_classes,
                                     :title => "#{issue.tracker.name}: #{issue.subject.truncate(100)} (#{issue.status.name})") + ": #{issue.subject}"
                           else
                             link_to("#{sep}#{oid}#{comment_suffix}",
                                     url,
                                     :class => issue.css_classes,
                                     :title => "#{issue.tracker.name}: #{issue.subject.truncate(100)} (#{issue.status.name})")
                           end
                  end
                when 'document'
                  if document = Document.visible.find_by_id(oid)
                    link = link_to(document.title, document_url(document, :only_path => only_path), :class => 'document')
                  end
                when 'version'
                  if version = Version.visible.find_by_id(oid)
                    link = link_to(version.name, version_url(version, :only_path => only_path), :class => 'version')
                  end
                when 'message'
                  if message = Message.visible.find_by_id(oid)
                    link = link_to_message(message, {:only_path => only_path}, :class => 'message')
                  end
                when 'forum'
                  if board = Board.visible.find_by_id(oid)
                    link = link_to(board.name, project_board_url(board.project, board, :only_path => only_path), :class => 'board')
                  end
                when 'news'
                  if news = News.visible.find_by_id(oid)
                    link = link_to(news.title, news_url(news, :only_path => only_path), :class => 'news')
                  end
                when 'project'
                  if p = Project.visible.find_by_id(oid)
                    link = link_to_project(p, {:only_path => only_path}, :class => 'project')
                  end
                when 'user'
                  u = User.visible.find_by(:id => oid, :type => 'User')
                  link = link_to_user(u, :only_path => only_path) if u
                end
              elsif sep == ':'
                name = remove_double_quotes(identifier)
                case prefix
                when 'document'
                  if project && document = project.documents.visible.find_by_title(name)
                    link = link_to(document.title, document_url(document, :only_path => only_path), :class => 'document')
                  end
                when 'version'
                  if project && version = project.versions.visible.find_by_name(name)
                    link = link_to(version.name, version_url(version, :only_path => only_path), :class => 'version')
                  end
                when 'forum'
                  if project && board = project.boards.visible.find_by_name(name)
                    link = link_to(board.name, project_board_url(board.project, board, :only_path => only_path), :class => 'board')
                  end
                when 'news'
                  if project && news = project.news.visible.find_by_title(name)
                    link = link_to(news.title, news_url(news, :only_path => only_path), :class => 'news')
                  end
                when 'commit', 'source', 'export'
                  if project
                    repository = nil
                    if name =~ %r{^(([a-z0-9\-_]+)\|)(.+)$}
                      repo_prefix, repo_identifier, name = $1, $2, $3
                      repository = project.repositories.detect {|repo| repo.identifier == repo_identifier}
                    else
                      repository = project.repository
                    end
                    if prefix == 'commit'
                      if repository && (changeset = Changeset.visible.where("repository_id = ? AND scmid LIKE ?", repository.id, "#{name}%").first)
                        link = link_to h("#{project_prefix}#{repo_prefix}#{name}"), {:only_path => only_path, :controller => 'repositories', :action => 'revision', :id => project, :repository_id => repository.identifier_param, :rev => changeset.identifier},
                                       :class => 'changeset',
                                       :title => truncate_single_line_raw(changeset.comments, 100)
                      end
                    else
                      if repository && User.current.allowed_to?(:browse_repository, project)
                        name =~ %r{^[/\\]*(.*?)(@([^/\\@]+?))?(#(L\d+))?$}
                        path, rev, anchor = $1, $3, $5
                        link = link_to h("#{project_prefix}#{prefix}:#{repo_prefix}#{name}"), {:only_path => only_path, :controller => 'repositories', :action => (prefix == 'export' ? 'raw' : 'entry'), :id => project, :repository_id => repository.identifier_param,
                                                                                               :path => to_path_param(path),
                                                                                               :rev => rev,
                                                                                               :anchor => anchor},
                                       :class => (prefix == 'export' ? 'source download' : 'source')
                      end
                    end
                    repo_prefix = nil
                  end
                when 'attachment'
                  attachments = options[:attachments] || []
                  attachments += obj.attachments if obj.respond_to?(:attachments)
                  if attachments && attachment = Attachment.latest_attach(attachments, name)
                    link = link_to_attachment(attachment, :only_path => only_path, :class => 'attachment')
                  end
                when 'project'
                  if p = Project.visible.where("identifier = :s OR LOWER(name) = :s", :s => name.downcase).first
                    link = link_to_project(p, {:only_path => only_path}, :class => 'project')
                  end
                when 'user'
                  u = User.visible.find_by("LOWER(login) = :s AND type = 'User'", :s => name.downcase)
                  link = link_to_user(u, :only_path => only_path) if u
                end
              elsif sep == "@"
                name = remove_double_quotes(identifier)
                u = User.visible.find_by("LOWER(login) = :s AND type = 'User'", :s => name.downcase)
                link = link_to_user(u, :only_path => only_path) if u
              end
            end
            (leading + (link || "#{project_prefix}#{prefix}#{repo_prefix}#{sep}#{identifier}#{comment_suffix}"))
          end
        end
      end
    end
  end
end