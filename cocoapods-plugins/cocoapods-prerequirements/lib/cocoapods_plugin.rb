#
#  Copyright © 2021 Yandex. All rights reserved.
#

Pod::HooksManager.register('cocoapods-prerequirements', :pre_install) do |context, options|
  Pod::UI.section('cocoapods-prerequirements') do
    return unless reqs_proc = options['prerequirements']

    reqs = Pod::Prerequirements.new(context.sandbox)
    reqs.instance_eval(&reqs_proc)
  end
end

module Pod
  class Resolver
    alias_method :old_specifications_for_dependency, :specifications_for_dependency

    define_method(:specifications_for_dependency) do |dependency, additional_requirements = []|
      additional_requirements = additional_requirements.dup

      pod_prerequirements = sandbox.pod_prerequirements
      requirement = pod_prerequirements[dependency.root_name]
      if requirement
        additional_requirements.unshift(requirement)
      end

      old_specifications_for_dependency(dependency, additional_requirements)
    end
  end
end

module Pod
  class Prerequirements
    def initialize(sandbox)
      @sandbox = sandbox
    end
    
    def pod(name, version)
      @sandbox.store_pod_prerequirement(name, version)
    end
  end
end

module Pod
  class Sandbox
    module Prerequirements
      attr_reader :pod_prerequirements

      def prerequirements_initialize
        @pod_prerequirements = {}
      end

      def store_pod_prerequirement(name, version)
        @pod_prerequirements[name] = Pod::Requirement.new(version)
      end
    end

    include Prerequirements

    alias_method :old_initialize, :initialize
    define_method(:initialize) do |args|
      old_initialize(*args)
      prerequirements_initialize()
    end
  end
end
