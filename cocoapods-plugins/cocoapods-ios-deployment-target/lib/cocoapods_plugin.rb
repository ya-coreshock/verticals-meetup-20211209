#
#  Copyright © 2021 Yandex. All rights reserved.
#

# This fixes warnings in Xcode 10 about pod target deployment targets
# See https://github.com/CocoaPods/CocoaPods/issues/8069

Pod::HooksManager.register('cocoapods-ios-deployment-target', :post_install) do |context, options|
  Pod::UI.section('cocoapods-ios-deployment-target') do
    # pod root name => (version | special symbol)
    # '10.0' – set specific version
    # '@' – do not override (leave as-is)
    # '&' – use project deployment version
    pod_overrides = options['overrides'] ||= {}
    pod_overrides = pod_overrides.transform_values(&:to_s)

    versions_by_spec_names = {}
    Pod::UI.message('– Collecting deployment targets', '', -4) do
      context.umbrella_targets.each do |target|
        target.specs.each  do |spec|
          root_name = Pod::Specification.root_name(spec.name)
          deployment_version = target.platform_deployment_target
          versions_by_spec_names[root_name] = deployment_version
        end
      end
    end

    def patch_project(project, pod_overrides, versions_by_spec_names)
      project_changed = false
      Pod::UI.section("– Patching project `#{project.path.basename}`", '', -4) do
        project.targets.each do |target|
          spec_names = versions_by_spec_names.keys
          spec_name = spec_names.find { |name| name == target.name || target.name.start_with?(name + '.') || target.name.start_with?(name + '-') }
          if spec_name
            min_deployment_target = if (version_override = pod_overrides[spec_name])
              case version_override
              when '@'
                nil
              when '&'
                versions_by_spec_names[spec_name]
              else
                version_override
              end
            else
              versions_by_spec_names[spec_name]
            end

            if min_deployment_target
              target_changed = false
              target.build_configurations.each do |config|
                if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < min_deployment_target.to_f
                  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = min_deployment_target
                  target_changed = true
                  project_changed = true
                end
              end
              if target_changed
                Pod::UI.message("– Set deployment target of `#{spec_name}` to `#{min_deployment_target}`")
              end
            else
              Pod::UI.message("– Ignore deployment target of `#{spec_name}`")
            end
          end
        end
        if project_changed
          project.mark_dirty!
          project.save
          # @coreshock: Yeap! Twice!
          project.save
          Pod::UI.message("– Project `#{project.path.basename}` saved")
        end
      end
    end

    patch_project(context.pods_project, pod_overrides, versions_by_spec_names)

    sub_projects = context.pods_project.files
      .select { |e| e.path.end_with?('xcodeproj') }
      .map { |e| Xcodeproj::Project.open(e.real_path) }
    sub_projects.each do |project|
      patch_project(project, pod_overrides, versions_by_spec_names)
    end
  end
end
