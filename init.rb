Redmine::Plugin.register :redmine_configurable_scm_ticket_id_prefix do
	name 'Redmine Configurable SCM Ticket ID Prefix'
	author 'Brett Patterson'
	description 'Allow admin to change the ticket ID prefix from "#" to something else to help resolve conflicts of other software reading the commit messages to reference tickets'
	version '1.0.1'

	settings :default => {'empty' => true}, :partial => 'settings/ticket_id_prefix_settings'

	requires_redmine :version_or_higher => '4.0.0'
end

Rails.configuration.to_prepare do
  require_dependency 'application_helper'
  unless ApplicationHelper.included_modules.include?(RedmineConfigurableScmTicketIdPrefix::Patches::ApplicationHelperPatch)
    ApplicationHelper.send(:prepend, RedmineConfigurableScmTicketIdPrefix::Patches::ApplicationHelperPatch)
  end

  require_dependency 'changeset'
  unless Changeset.included_modules.include?(RedmineConfigurableScmTicketIdPrefix::Patches::ChangesetPatch)
    Changeset.send(:prepend, RedmineConfigurableScmTicketIdPrefix::Patches::ChangesetPatch)
  end
end
