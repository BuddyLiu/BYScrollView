Pod::Spec.new do |s|
  s.name             = 'BYScrollView'
  s.version          = '1.0.0'
  s.summary          = 'A SwiftUI ScrollView wrapper that observes content size and scroll offset, consistent across iOS 15+.'
  s.description      = <<-DESC
                       BYScrollView is a SwiftUI ScrollView wrapper providing consistent scroll geometry observation
                       (contentOffset / contentSize / containerSize) across iOS 15+. It uses GeometryReader + PreferenceKey
                       on iOS 15-17 and the native onScrollGeometryChange on iOS 18+, with single-instance callbacks,
                       multi-instance dictionary callbacks, nested isolation control and parent-level aggregation.
  DESC
  s.homepage         = 'https://github.com/BuddyLiu/BYScrollView'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'BuddyLiu' => 'https://github.com/BuddyLiu' }
  s.source           = { :git => 'https://github.com/BuddyLiu/BYScrollView.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'

  s.source_files     = 'Sources/BYScrollView/**/*.swift'
  s.frameworks       = 'SwiftUI'
  s.swift_versions   = ['5.9']

  s.requires_arc     = true
end