#
# Be sure to run `pod lib lint JKCommunity.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'JKCommunity'
  s.version          = '0.1.0'
  s.summary          = 'Firebase를 이용한 유저 서비스'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/monibu1548/JKCommunity'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'monibu1548' => 'monibu1548@gmail.com' }
  s.source           = { :git => 'https://github.com/monibu1548/JKCommunity.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '13.0'

  s.source_files = 'JKCommunity/Classes/**/*'
  
  # s.resource_bundles = {
  #   'JKCommunity' => ['JKCommunity/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.static_framework = true
  s.dependency 'JKFirebaseSDK'
  s.dependency 'JKExtension'
  s.dependency 'AFNetworking', '~> 2.3'
  s.dependency 'RxSwift', '~> 5.0.1'
  s.dependency 'RxOptional', '~> 4.1.0'
end
