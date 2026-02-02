Pod::Spec.new do |s|
  s.name             = 'Auth0UIComponents'
  s.version          = '1.0.0'
  s.summary          = "Auth0UIComponents SDK for Apple platforms"
  s.description      = <<-DESC
                        Auth0UIComponents SDK for iOS, macOS and visionOS apps.
                        DESC
  s.homepage         = 'https://github.com/auth0/Auth0UIComponents.swift'
  s.license          = 'MIT'
  s.authors          = { 'Auth0' => 'support@auth0.com', 'Nandan Prabhu' => 'nandan.prabhup@okta.com' }
  s.source           = { :git => 'https://github.com/auth0/Auth0.swift.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/auth0'
  s.source_files     = 'Auth0UIComponents/**/*.swift'
  s.resource_bundles = { s.name => 'Auth0UIComponents/PrivacyInfo.xcprivacy' }
  s.swift_versions   = ['5.0']

  s.dependency 'Auth0', '2.16.1'

  s.ios.deployment_target   = '16.0'
  s.osx.deployment_target   = '14.0'
  s.visionos.deployment_target = '1.0'
end