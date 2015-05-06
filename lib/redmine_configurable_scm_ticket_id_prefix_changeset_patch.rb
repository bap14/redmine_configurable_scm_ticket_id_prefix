require_dependency 'changeset'

module RedmineConfigurableScmTicketIdPrefixChangesetPatch
  def self.included(base)
    base.send(:include, InstanceMethods)

    base.class_eval do
      # creates 2 new methods: #{param1}_with_#{param2} and #{param1}_without_#{param2}
      # where the latter is the original method
      alias_method_chain :scan_comment_for_issue_ids, :alternate_ticket_id_prefix
    end
  end

  module InstanceMethods
    TIMELOG_RE = /
      (
      ((\d+)(h|hours?))((\d+)(m|min)?)?
      |
      ((\d+)(h|hours?|m|min))
      |
      (\d+):(\d+)
      |
      (\d+([\.,]\d+)?)h?
      )
      /x
    
    def scan_comment_for_issue_ids_with_alternate_ticket_id_prefix
      return if comments.blank?
        # keywords used to reference issues
        ref_keywords = Setting.commit_ref_keywords.downcase.split(",").collect(&:strip)
        ref_keywords_any = ref_keywords.delete('*')
        # keywords used to fix issues
        fix_keywords = Setting.commit_update_keywords_array.map {|r| r['keywords']}.flatten.compact

        kw_regexp = (ref_keywords + fix_keywords).collect{|kw| Regexp.escape(kw)}.join("|")

        referenced_issues = []

      #############################################################################
      ## Prep alternate ticket id prefix
      alt_id_prefix = Setting.plugin_redmine_configurable_scm_ticket_id_prefix["ticket_id_prefix"].downcase.split(",").collect(&:strip)

      # Revert to the standard Redmine usage if no customization is provided
      if alt_id_prefix.nil? || alt_id_prefix.empty?
        alt_id_prefix = [ "#" ]
      end

      alt_id_prefix_regexp = alt_id_prefix.collect{|aip| Regexp.escape(aip)}.join("|")
      #############################################################################

      comments.scan(/([\s\(\[,-]|^)((#{kw_regexp})[\s:]+)?((?:#{alt_id_prefix_regexp})\d+(\s+@#{TIMELOG_RE})?([\s,;&]+(?:#{alt_id_prefix_regexp})\d+(\s+@#{TIMELOG_RE})?)*)(?=[[:punct:]]|\s|<|$)/i) do |match|
        action, refs = match[2].to_s.downcase, match[3]
        next unless action.present? || ref_keywords_any

        refs.scan(/(?:#{alt_id_prefix_regexp})(\d+)(\s+@#{TIMELOG_RE})?/).each do |m|
          issue, hours = find_referenced_issue_by_id(m[0].to_i), m[2]
          if issue && !issue_linked_to_same_commit?(issue)
            referenced_issues << issue
            # Don't update issues or log time when importing old commits
            unless repository.created_on && committed_on && committed_on < repository.created_on
              fix_issue(issue, action) if fix_keywords.include?(action)
              log_time(issue, hours) if hours && Setting.commit_logtime_enabled?
            end
          end
        end
      end

      referenced_issues.uniq!
      self.issues = referenced_issues unless referenced_issues.empty?
    end
  end

  # Here because internal calls to this method apparently don't get mapped
  def scan_comment_for_issue_ids
    scan_comment_for_issue_ids_with_alternet_ticket_id_prefix
  end
end

Changeset.send(:include, RedmineConfigurableScmTicketIdPrefixChangesetPatch)
