# Redmine Configurable SCM Ticket ID Prefix

Provides the administrator functionality to adjust the ticket ID prefix used in SCM messages.  This will allow you to change it from the default "#" to any other string(s).

This will help if you're using two separate systems to track issues.  For instance, if you have an internal development team and a development vendor but the repository is hosted elsewhere and that system automatically associates "#" with their tickets.

# Installation

Install just like all other redmine plugins.

# Usage

Once installed, under Administrator > Plugins click the "Configure" link for the Redmine Configurable SCM Ticket ID Prefix plugin.  Enter the prefix(es) you would like to use to reference tickets separated by comma.  For example "#,rm" would allow both "#" or "rm" to immediately precede the ticket number.  Leave it blank to return to default behavior.

# Version History

## 0.0.2

Compatibility with Redmine 2.6

## 0.0.1

Initial release
