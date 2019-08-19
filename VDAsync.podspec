Pod::Spec.new do |s|
s.name             = 'VDAsync'
s.version          = '0.6.0'
s.summary          = 'A short description of VDAsync.'

s.description      = <<-DESC
TODO: Add long description of the pod here.
DESC

s.homepage         = 'https://github.com/dankinsoid/VDAsync'
# s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
s.license          = { :type => 'MIT', :file => 'LICENSE' }
s.author           = { 'voidilov' => 'voidilov@gmail.com' }
s.source           = { :git => 'https://github.com/dankinsoid/VDAsync.git', :tag => s.version.to_s }

s.ios.deployment_target = '10.0'
s.swift_versions = '5.0'
s.source_files = 'Sources/VDAsync/**/*'

s.dependency 'UnwrapOperator', '~> 0.1.0'

s.default_subspec = 'Lite'

s.subspec 'Lite' do |lite|
end

s.subspec 'RxSwift' do |rx|
    rx.dependency	'RxSwift', '~> 5'
    rx.source_files = 'Sources/**/*'
end

end