#
# Be sure to run `pod lib lint CDYahooKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'CDYahooKit'
  s.version          = '0.9.24'
  s.summary          = 'An extensive Objective C wrapper for the Yahoo Developers Social and Fantasy Football APIs.'
  s.description      = <<-DESC
This Objective C wrapper covers all possible network endpoints and responses for the Yahoo Developers Social and Fantasy Football API's.
                       DESC
  s.homepage         = 'https://github.com/chrisdhaan/CDYahooKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Christopher de Haan' => 'contact@christopherdehaan.me' }
  s.source           = { :git => 'https://github.com/chrisdhaan/CDYahooKit.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/dehaan_solo'

  s.ios.deployment_target = '8.0'
  s.requires_arc = true

  s.subspec 'Core' do |core|
    core.source_files = 'CDYahooKit/Classes/Core/**/*.{h,m}'
    core.frameworks = 'CoreLocation'
    core.dependency 'Overcoat', '~> 4.0.0-beta.2'
    core.dependency 'CDYahooKit/OAuth'
  end

  s.subspec 'OAuth' do |oauth|
    oauth.source_files = 'CDYahooKit/Classes/OAuth/**/*.{h,m}'
    oauth.dependency 'CDOAuth1Kit'
  end
end
