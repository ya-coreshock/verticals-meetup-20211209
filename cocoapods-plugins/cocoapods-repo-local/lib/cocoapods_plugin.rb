#
#  Copyright © 2021 Yandex. All rights reserved.
#

PODPATHS_REGISTRY = {}
PODSPECS_REGISTRY = {}

Pod::HooksManager.register('cocoapods-repo-local', :source_provider) do |context, options|
  Pod::UI.section('cocoapods-repo-local') do
    sandbox = Pod::Config.instance.sandbox

    podfile_path = Pod::Config.instance.podfile.defined_in_file.dirname
    podpaths_dsl = Pod::LocalRegistrySource::DSL.new(sandbox, podfile_path)

    pod_registry = options['pod_registry']
    if pod_registry
      podpaths_proc = pod_registry
      podpaths_dsl.instance_eval(&podpaths_proc)
    end

    path_sources = options['path_sources']
    if path_sources
      path_sources.each do |dir|
        Pod::UI.section("– Registering paths from `#{dir}` directory", '', -4) do
          glob = Pathname(podfile_path + dir).join('**', '*.podspec')
          Pathname.glob(glob).sort.each do |full_path|
            path = full_path.relative_path_from(podfile_path)
            begin
              podspec = Pod::Specification.from_file(full_path)
              podpaths_dsl.pod(podspec.name, { :path => path })
              Pod::UI.message("– #{podspec.name} (from `#{path.relative_path_from(Pathname.new(dir))}`)")
            rescue
              Pod::UI.warn("Skipping path `#{path}` because podspec contains errors.")
              next
            end
          end
        end
      end
    end

    spec_sources = options['spec_sources']
    if spec_sources
      spec_sources.each do |dir|
        Pod::UI.section("– Registering podspecs from `#{dir}` directory", '', -4) do
          glob = Pathname(podfile_path + dir).join('**', '*.podspec{.json,}')
          Pathname.glob(glob).sort.each do |full_path|
            path = full_path.relative_path_from(podfile_path)
            begin
              podspec = Pod::Specification.from_file(full_path)
              podpaths_dsl.pod(podspec.name, { :podspec => path })
              Pod::UI.message("– #{podspec.name} (from `#{path.relative_path_from(Pathname.new(dir))}`)")
            rescue
              Pod::UI.warn("Skipping podspec `#{path}` because it contains errors.")
              next
            end
          end
        end
      end
    end
  end
end

module Pod
  class LocalRegistrySource
    class DSL
      def initialize(sandbox, podfile_path)
        @sandbox = sandbox
        @podfile_path = podfile_path
      end

      def pod(name, hash)
        if hash[:path]
          path = Pathname.new(hash[:path])
          PODPATHS_REGISTRY[name] = path.to_s
          spec_path = @podfile_path + path
          @sandbox.store_local_path(name, spec_path)
          podspec = Specification.from_file(spec_path)
          @sandbox.store_podspec(podspec.name, podspec, true, true)
        elsif hash[:podspec]
          path = Pathname.new(hash[:podspec])
          PODSPECS_REGISTRY[name] = path.to_s
          spec_path = @podfile_path + path
          begin
            podspec = Specification.from_file(spec_path)
            @sandbox.store_podspec(podspec.name, podspec, true, true)
          rescue
            Pod::UI.warn("Skipping `#{full_path.relative_path_from(podfile_path)}` because the podspec contains errors.")
          end
        else
          raise ArgumentError, "Neither :path nor :podspec passed as argument"
        end
      end
    end
  end
end

module Pod
  class Dependency
    alias_method :old_initialize, :initialize

    define_method(:initialize) do |name, *requirements|
      root_name = Pod::Specification.root_name(name)
      if root_name
        if !requirements.empty?
          # @coreshock: Clean-up strange empty Array's and Hash's
          while requirements.first.respond_to?(:empty?) && requirements.first.empty? do
            requirements.shift
          end
          while requirements.last.respond_to?(:empty?) && requirements.last.empty? do
            requirements.pop
          end

          # @coreshock: Replace String keys with Symbol keys
          if requirements.last.is_a?(Hash)
            last_podpath = requirements.last.delete("path")
            if last_podpath
              requirements.last[:path] = last_podpath
            end
            last_podspec = requirements.last.delete("podspec")
            if last_podspec
              requirements.last[:podspec] = last_podspec
            end
          end
        end

        # @coreshock: Add file path requirement if there is no requirements
        if requirements.empty?
          podpath_path = PODPATHS_REGISTRY[root_name]
          if podpath_path
            requirements.push({ :path => podpath_path })
          end
          podspec_path = PODSPECS_REGISTRY[root_name]
          if podspec_path
            requirements.push({ :podspec => podspec_path })
          end
        end
      end

      old_initialize(name, *requirements)
    end
  end
end
