require 'xcodeproj'
p = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp.xcodeproj'
proj = Xcodeproj::Project.open(p)
t = proj.targets.find { |x| x.name == 'ioscrmapp' }
mg = proj.main_group['ioscrmapp']
bolt = mg.groups.find { |g| g.display_name == 'BoltUIKit' }
travel = bolt.groups.find { |g| g.display_name == 'Travel' }
comps = travel.groups.find { |g| g.display_name == 'Components' }

fp = '/Users/xianlin/Documents/00-running/17-workspace_crmapp/ioscrmapp/ioscrmapp/BoltUIKit/Travel/Components/BoltTravelDreamscape.swift'
ref = comps.new_file(fp)
t.source_build_phase.add_file_reference(ref)
proj.save
puts "Added BoltTravelDreamscape.swift"