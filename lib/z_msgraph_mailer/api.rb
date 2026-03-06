require 'net/http'
require 'uri'
require 'json'

module ZMsgraphMailer
  class Api

    attr_accessor :settings, :access_token

    DEFAULTS = {
      :send_url         => "https://graph.microsoft.com/v1.0/users/$$sender_email$$/sendMail",
      :oauth2_url       => "https://login.microsoftonline.com/$$tenant_id$$/oauth2/v2.0/token",
      :graph_api_scope  => "https://graph.microsoft.com/.default",
      :ssl_verify       => true
    }

    def self.config
      @config ||= DEFAULTS.merge({
                    sender_email: "from@example.org",
                    client_id: "CLIENT_ID",
                    tenant_id: "TENANT_ID",
                    client_secret: "CLIENT_SECRET",
                    save_to_sent_items: false
                  }).with_indifferent_access
    end

    def self.config=(cfg)
      @config = cfg.with_indifferent_access.merge(DEFAULTS)
    end

    def initialize(values)
      self.settings = ZMsgraphMailer::Api.config.merge(values)
    end

    def validate_settings
      @invalid_keys = []
      [ :send_url, :oauth2_url, :graph_api_scope ].all? { |key|
        begin
          u = URI(settings[key])
          @invalid_keys << key unless u.scheme == "https" && u.path.present?
        rescue
          @invalid_keys << key
        end
      } 
      
      [ :sender_email, :client_id, :tenant_id, :client_secret ].all? { |key| 
        @invalid_keys << key unless settings[key].present?
      }
      return @invalid_keys.empty?
    end

    def deliver!(mail)
       unless validate_settings
        raise ZMsgraphMailerError.new("Invalid settings: the following key(s) are missing " \
                                      "or do not contain a valid value: #{@invalid_keys.inspect}")
      end
      unless access_token = get_access_token
        raise ZMsgraphMailerError.new("Error retrieving access token for Graph API")
      end

      message_payload = { 
        message: get_message_content(mail),
        saveToSentItems: settings[:save_to_sent_items] === true
      }

      # Send email
      uri = URI(settings[:send_url].gsub("$$sender_email$$", settings[:sender_email]))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri)
      request['Authorization'] = "Bearer #{access_token}"
      request['Content-Type'] = 'application/json'
      request.body = message_payload.to_json

      # puts "\n\n#{pp(message_payload)}\n\n"

      response = http.request(request)
      # puts "Response Code: #{response.code.inspect}"
      # puts "Response Body: #{response.body.inspect}"

      unless response.code.to_i == 202
        error_json = JSON.parse(response.body) rescue { "error" => { "message" => "Unknown Error" } }
        error_msg = error_json.dig('error', 'message') || 'Unknown error'
        raise ZMsgraphMailerError.new("Ms Graph sendEmail call error (response code #{response.code}): #{error_msg}")
      end
    end


    def get_access_token
      if token = fetch_token_from_cache(settings[:tenant_id])
        return token
      end
  
      uri = URI(settings[:oauth2_url].gsub("$$tenant_id$$", settings[:tenant_id]))
      res = Net::HTTP.post_form(uri, {
              "client_id"     => settings[:client_id],
              "scope"         => settings[:graph_api_scope],
              "client_secret" => settings[:client_secret],
              "grant_type"    => "client_credentials" })
      if res.is_a?(Net::HTTPSuccess)
        begin
          json = JSON.parse(res.body)
          token = json["access_token"]
          expires_in = json['expires_in'] || 3600 # seconds
          cache_token(settings[:tenant_id], token, expires_in)
          token
        rescue 
          raise ZMsgraphMailerError.new("Error parsing JSON response for access token. Response Body: #{res.body.inspect}")
        end
      else
        raise ZMsgraphMailerError.new("HTTP Error (#{res.status}) while retrieving for access token. Response Body: #{res.body.inspect}")
      end
    end

    def fetch_token_from_cache(tenant_id)
      Rails.cache.read("ms-graph-token-#{settings[:tenant_id]}")
    end

    def cache_token(tenant_id, token, expires_in)
      Rails.cache.write("ms-graph-token-#{settings[:tenant_id]}", token, expires_in: expires_in.to_i)
    end

    def get_message_content(mail)
      p = {
        from: get_sender(mail.from),
        subject: mail.subject.to_s,
        body: get_body(mail),
        toRecipients: get_recipients(mail.to),
        ccRecipients: get_recipients(mail.cc),
        bccRecipients: get_recipients(mail.bcc),
        replyTo: get_recipients(mail.reply_to),
        attachments: get_attachments(mail)
      }
      p.compact
    end

    def get_sender(from_email)
      if from_email.present?
        { emailAddress: { address: from_email.to_s.strip } }
      end
    end

    def get_recipients(recipients)
      if recipients.is_a?(Array)
        recipients.reject { |r| r.blank? }.map { |r| { emailAddress: { address: r.to_s.strip } } }
      else
        nil
      end
    end

    def get_body(mail)
      body =  unless mail.multipart?
                { contentType: mail.content_type&.start_with?('text/html') ? 'HTML' : 'Text', content: mail.body.decoded }
              else
                if (html = mail.html_part).present?
                  { contentType: 'HTML', content: html.body.decoded }
                elsif (text = mail.text_part).present?
                  { contentType: 'Text', content: text.body.decoded }
                end
              end
      raise ZMsgraphMailerError.new("Mail body content is empty!") if body.blank?
      body
    end

    def get_attachments(mail)
      mail.attachments.map do |attachment|
        { '@odata.type': '#microsoft.graph.fileAttachment',
          name: attachment.filename.to_s,
          contentId: attachment.cid,
          isInline: attachment.inline? ? true : false,
          contentType: attachment.mime_type.to_s,
          contentBytes: Base64.strict_encode64(attachment.body.decoded) }
      end
    end

  end
end