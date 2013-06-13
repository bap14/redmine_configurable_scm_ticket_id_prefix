require 'redmine'
require 'redmine_configurable_scm_ticket_id_prefix_changeset_patch'
require 'redmine_configurable_scm_ticket_id_prefix_application_helper_patch'

Redmine::Plugin.register :redmine_configurable_scm_ticket_id_prefix do
	name 'Redmine Configurable SCM Ticket ID Prefix'
	author 'Brett Patterson'
	description 'Allow admin to change the ticket ID prefix from "#" to something else to help resolve conflicts of other software reading the commit messages to reference tickets'
	version '0.0.1'

	settings :default => {'empty' => true}, :partial => 'settings/ticket_id_prefix_settings'

	requires_redmine :version_or_higher => '2.0.3'
end
