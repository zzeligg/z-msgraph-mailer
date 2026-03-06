Gem::Specification.new do |s|
  s.name        = 'z-msgraph-mailer'
  s.version     = '0.1.0'

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = [ "lib" ]
  s.authors = [ "Charles Bedard" ]
  s.email = ["zzeligg@icloud.com" ]
  s.date = "2026-03-03"
  s.license = "MIT"
  s.homepage = "https://github.com/zzeligg/z-msgraph-mailer"
  s.summary = "ActionMailer Delivery Method for Rails applications"
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.files = Dir[ "CHANGELOG", "README.rdoc", "lib/**/*" ]

  # Runtime dependencies
  s.add_dependency "actionmailer", "~> 8.0"
  s.add_dependency "activesupport", "~> 8.0"
end

