# ZMsgraphMailer

An ActionMailer `delivery_method` that implements the Microsoft Graph API to send email messages.

## Features

 * Supports configuration for multiple sender (`tenant_id`), which can be dynamically set for each sent message if needed.
 * Supports `fileAttachments` (either inline or not)

## Requirements

 * ActionMailer and ActiveSupport (Rails) 8.0
 * Ruby 3.3.0+

## Installation

Add to your Gemfile:

```ruby
  gem "z-msgraph-mailer", git: "https://github.com/zzeligg/z-msgraph-mailer.git"
```
## Configuration

Create an initializer such as `config/initializers/z-msgraph-mailer.rb`:

```ruby
  ActionMailer::Base.delivery_method = :ms_graph

  ZMsgraphMailer.config = { 
    sender_email: "from@example.org",      # one of the user's authorized sender email address 
    client_id: "CLIENT_ID",
    tenant_id: "TENANT_ID",
    client_secret: "CLIENT_SECRET",
    save_to_sent_items: false
  }
```
## Overriding values when Mailer action is called

You can override the config dynamically in your `Mailer` class, user an `after_action` filter.

For example, let's say you have a multiple tenants in your application, where an `Account` model
holds the configuration to send emails in a serialized attribute named `mailer_settings`:

```ruby
class ApplicationMailer < ActionMailer::Base

  after_action :set_sender_params

  def notify_user(user)
    @user = user
    mail(to: @user.email,
         subject: "Notification from us")
  end

  protected

  def set_sender_params
    sender_settings = @user.mailer_settings
    mail.delivery_method.settings.merge!(settings.symbolize_keys)
  end
end
```

## License

`ZMsgraphMailer` is released under the MIT license.

## Support

Source code, documentation, bug reports, feature requests or anything else is at

  * http://github.com/zzeligg/z-msgraph-mailer
