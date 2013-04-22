# Copyright 2011-2013 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.

require 'yard'

namespace :docs do

  task :yard => [:update_readme, :update_core] do
    sh "yard"
  end

  desc "Builds a distributable documentation zip file at ./pkg/aws-docs.zip"
  task :package => [:clobber, :yard, "pkg/aws-docs.zip"]

  task :clobber do
    rm_rf "doc"
    rm_rf "pkg/aws-docs.zip"
  end

  directory "pkg"
  file "pkg/aws-docs.zip" => ["pkg", "doc"] do |t|
    rm_f t.name
    sh "zip -r #{t.name} doc"
  end

  task :update_readme do

    def name svc
      AWS::SERVICES[svc][:full_name]
    end

    require 'aws/core'

    supported = {}

    AWS::SERVICES.keys.each do |svc|
      apis = Dir.glob("./lib/aws/api_config/#{svc}*.yml")
      apis = apis.map{|api| api.match(/\d{4}-\d{2}-\d{2}/)[0] }
      name = AWS::SERVICES[svc][:full_name]
      supported[svc] = apis
    end
    supported['S3'] = ['2006-03-01']

    rows = []
    supported.sort_by{|svc,api| svc.downcase }.each do |(svc,apis)|
      rowspan = apis.length > 1 ? " rowspan=\"#{apis.length}\"" : ''
      rows << "    <tr>"
      rows << "      <td#{rowspan}>AWS::#{svc}</td>"
      rows << "      <td>#{apis.first}</td>"
      rows << "      <td#{rowspan}>#{name(svc)}</td>"
      rows << "    </tr>"
      apis[1..-1].each do |api|
        rows << "    <tr>"
        rows << "      <td>#{api}</td>"
        rows << "    </tr>"
      end
    end
    rows = rows.join("\n")

    table = <<-HTML
  <table class="supported-services" border="1">
    <thead>
      <th>Class</th>
      <th>API Version</th>
      <th>AWS Service Name</th>
    </thead>
    <tbody>
  #{rows}
    </tbody>
  </table>
  HTML

    update_file(
      'README.md',
      table,
      /class="supported-services"/,
      /<\/table>/
    )
  end

  # updates the list of supported services in lib/aws/core.rb
  task :update_core do

    require 'aws/core'

    svcs = AWS::SERVICES.keys.sort_by(&:downcase).map{|svc| "# * {AWS::#{svc}}" }

    start = '# # Supported Services'
    stop = '# # Configuration'

    update_file(
      'lib/aws/core.rb',
      "#{start}\n#\n#{svcs.join("\n")}\n#\n#{stop}\n",
      /^#{start}/,
      /^#{stop}/
    )

  end

end

desc "Builds the API documentation to ./doc/"
task :docs => ['docs:yard']

def update_file filename, content, start_pattern, stop_pattern

  lines = []
  skip = false

  File.read(filename).lines.each do |line|

    if line.match(start_pattern)
      lines << content
      skip = true
    end

    lines << line unless skip

    if line.match(stop_pattern)
      skip = false
    end
  end

  File.open(filename, 'w') {|f| f.write(lines.join) }

end
