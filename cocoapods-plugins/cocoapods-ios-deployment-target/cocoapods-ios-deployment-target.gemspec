# frozen_string_literal: true

require_relative "lib/version"

Gem::Specification.new do |spec|
  spec.name          = "cocoapods-ios-deployment-target"
  spec.version       = Cocoapods::PatchDeploymentTarget::VERSION
  spec.authors       = ["Alexey Aleshkov"]
  spec.email         = ["coreshock@yandex-team.ru"]

  spec.summary       = "Set minimum iOS deployment-target"
  spec.description   = "Set minimum iOS deployment-target"
  spec.license       = "MPL-2.0"
  spec.homepage      = "https://yandex.ru/"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage

  spec.files = Dir['lib/**/*.rb']
  spec.require_paths = ["lib"]
end
