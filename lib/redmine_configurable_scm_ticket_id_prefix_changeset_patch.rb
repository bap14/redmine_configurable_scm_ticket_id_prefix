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
		def scan_comment_for_issue_ids_with_alternate_ticket_id_prefix
			return if comments.blank?
			# keywords used to reference issues
			ref_keywords = Setting.commit_ref_keywords.downcase.split(",").collect(&:strip)
			ref_keywords_any = ref_keywords.delete('*')
			# keywords used to fix issues
			fix_keywords = Setting.commit_fix_keywords.downcase.split(",").collect(&:strip)
		
			kw_regexp = (ref_keywords + fix_keywords).collect{|kw| Regexp.escape(kw)}.join("|")

			#############################################################################
			## Prep alternate ticket id prefix
			alt_id_prefix = Setting.plugin_redmine_configurable_scm_ticket_id_prefix["ticket_id_prefix"].downcase.split(",").collect(&:strip)

			# Revert to the standard Redmine usage if no customization is provided
			if alt_id_prefix.nil? || alt_id_prefix.empty?
				alt_id_prefix = [ "#" ]
			end

			alt_id_prefix_regexp = alt_id_prefix.collect{|aip| Regexp.escape(aip)}.join("|")
			#############################################################################
		
			referenced_issues = []
		
			comments.scan(/([\s\(\[,-]|^)((#{kw_regexp})[\s:]+)?((?:#{alt_id_prefix_regexp})\d+(\s+@#{Changeset::TIMELOG_RE})?([\s,;&]+(?:#{alt_id_prefix_regexp})\d+(\s+@#{Changeset::TIMELOG_RE})?)*)(?=[[:punct:]]|\s|<|$)/i) do |match|
				action, refs = match[2], match[3]
				next unless action.present? || ref_keywords_any
		
				refs.scan(/(?:#{alt_id_prefix_regexp})(\d+)(\s+@#{Changeset::TIMELOG_RE})?/).each do |m|
					issue, hours = find_referenced_issue_by_id(m[0].to_i), m[2]
					if issue
						referenced_issues << issue
						fix_issue(issue) if fix_keywords.include?(action.to_s.downcase)
						log_time(issue, hours) if hours && Setting.commit_logtime_enabled?
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
