# First we pull in the standard API hooks.
require 'sketchup.rb'
require 'fixSolid15'


#global variables defining geometry
$w= 0.1.m
$h= 0.13.m
$dBig = 0.001.m
$dSmall = 0.0005.m
$l = 0.3.m
$tip = 0.04.m
$tiph = 0.06.m
$nbTruss=5






def create_truss
	t= Truss.new
	c1 = t.addConstraint(Constraint::DISPLACEMENT,0,"123","Battery")
	c2 = nil #t.addConstraint(Constraint::FORCE,40,"3","EngineUp")
	a1 = add_arm t,0,$w/2,c1,c2
	a2 = add_arm t,90,$w/2,c1,c2
	a3 = add_arm t,180,$w/2,c1,c2
	a4 = add_arm t,270,$w/2,c1,c2
	t.addStick $dBig,a1[2],a2[2]
	t.addStick $dBig,a2[2],a3[2]
	t.addStick $dBig,a3[2],a4[2]
	t.addStick $dBig,a4[2],a1[2]
	t.addStick $dBig,a1[0],a1[1]
	t.addStick $dBig,a2[0],a2[1]
	t.addStick $dBig,a3[0],a3[1]
	t.addStick $dBig,a4[0],a4[1]
    t
end
def create_z88
	z88_path="D:\\ehubin\\Documents\\Dev\\z88\\"
	dirpath=File.join(z88_path,"test_")
	if !Dir.exists?(dirpath)
		Dir.mkdir(dirpath)
	end
	newDir = Dir.new(dirpath)
	create_truss.to_z88 newDir, Dir.new(z88_path)
end

def create_3dprint_grid
	res=[]
	idx=0
	Sketchup.active_model.entities.each {|elem|
	  x1=elem.get_attribute( "link","x1")
	  if (x1)
		res[idx] = elem
		idx+=1
		res[idx] = Geom::Point3d.new elem.get_attribute( "link","x1"),elem.get_attribute( "link","y1"),elem.get_attribute( "link","z1")
		idx+=1
		res[idx] = Geom::Point3d.new elem.get_attribute( "link","x2"),elem.get_attribute( "link","y2"),elem.get_attribute( "link","z2")
		idx+=1
	  end 
	}
	grid_size = 12.m
	grid_length=Math.sqrt(idx/3).ceil
	grid= Geom::Vector3d.new(0,0,100.m)
	align_to = Geom::Vector3d.new 1,0,0
	(idx/3).times do |j|
		pt1 = res[1+3*j]
		pt2 = res[2+3*j]
		v = pt1-pt2
		v.normalize!
		m= Geom::Vector3d.new((pt1.x+pt2.x)/2,(pt1.y+pt2.y)/2,(pt1.z+pt2.z)/2)
		mid = Geom::Point3d.new m.x,m.y,m.z
		m.reverse!
		
		
		angle = Math.acos(v.dot align_to)
		if( angle.abs < 0.0001 )
			axis = Geom::Vector3d.new 0,1,0 
		elsif( (angle-Math::PI).abs < 0.0001 )
			axis = Geom::Vector3d.new 0,1,0
		else
			axis = v*align_to
		end
		rot = Geom::Transformation.rotation(mid,axis,angle)
		puts "#{mid}|#{axis}|#{Math.acos(v.dot align_to)}|#{v}"
		
		
		tr = Geom::Transformation.new m+grid
		res[3*j].transform!(rot).transform!(tr)
		
		if ((j+1) %grid_length == 0)
			grid +=[-((grid_length-1)*grid_size),grid_size,0]
		else
			grid +=[grid_size,0,0]
		end
	end
end





def add_arm t,angle,dist,batteryConst,engineConst
   rot = Geom::Transformation.rotation [0,0,0], [0,0,1], angle*(Math::PI)/180
   
   
   pt =[]
   pt[1] = Geom::Point3d.new dist,$w/2,0
   v1 = Geom::Vector3d.new $l,-($w-$tip)/2,0
   pt[2] = Geom::Point3d.new dist,-$w/2,0
   v2 = Geom::Vector3d.new $l,($w-$tip)/2,0
   pt[3] = Geom::Point3d.new dist,0,-$h
   v3 = Geom::Vector3d.new $l,0,($h-$tiph)
   
   pt[1].transform! rot
   pt[2].transform! rot
   pt[3].transform! rot
   v1.transform! rot
   v2.transform! rot
   v3.transform! rot
   v=v3.clone
   v.length = $l/(2*$nbTruss)
   pt[3].offset!(v)
   ms1 = t.addMultiStick $dBig,pt[1],$nbTruss,[v1,$l]
   ms1.addStick $dBig,$dBig*2,t
   ms2 = t.addMultiStick $dBig,pt[2],$nbTruss,[v2,$l]
   ms2.addStick $dBig,$dBig*2,t
   ms3 = t.addMultiStick $dBig,pt[3],$nbTruss-1,[v3,$l*(1-1.0/$nbTruss)]
   ms3.addStick $dBig,$dBig*2,t
   t.connectLadder(ms1,ms2,$dSmall,1,$nbTruss)
   #t.connectLadder(ms1,ms2,$dBig,0,0) #Big rod on first ladder
   t.connectTriangle(ms1,0,ms3,0,$dSmall,$nbTruss)
   t.connectTriangle(ms2,0,ms3,0,$dSmall,$nbTruss)
   batteryConst.addNode(ms3.getNode(0))
   e1 = t.addConstraint(Constraint::FORCE,40,"3","EngineUp#{angle}1")
   e1.addNode(ms1.getNode(ms1.nbElem))
   e2 = t.addConstraint(Constraint::FORCE,40,"3","EngineUp#{angle}2")
   e2.addNode(ms2.getNode(ms2.nbElem))
   #engineConst.addNode(ms1.getNode(ms1.nbElem))
   #engineConst.addNode(ms2.getNode(ms2.nbElem))
   #return attachement nodes
   [ ms1.getNode(0),ms2.getNode(0),ms3.getNode(0)]
end



def draw_copter
 

  Sketchup.active_model.options["UnitsOptions"]["LengthUnit"]=2  
  Sketchup.active_model.entities.clear!

  t = create_truss
  t.draw
  lengthReport = t.getLength
  weight = 0 
  puts lengthReport
  lengthReport.each do |d,l|
	weight += 3.1415*l*(d.to_f)*(d.to_f)*1500000/4
	end
  puts "Estimated CF weight #{weight} gr\n"
  puts "Connectors total volume #{2.54*2.54*2.54*t.getConnectorVolume} cm3\n"
  puts "Connectors total weight #{2.54*2.54*2.54*0.45*t.getConnectorVolume} gr\n"
  end
  
 def myTrim (v1,v2)
	res = v1.trim(v2)
	 if(res == nil)
		puts "Trim failed for #{v1} and #{v2}"
		v1.name
		Sketchup.active_model.start_operation("FixSolids", true)
		FixSolids.risky(true)
		FixSolids.coplan(true)
		FixSolids.fixSolid(v2)
		Sketchup.active_model.commit_operation
		res=v2
	 end
	 return res
 end
 
 def myUnion(v1,v2)
	res = v1.union(v2)
	 if(res == nil)
		puts "Union failed for #{v1} and #{v2}"
		Sketchup.active_model.start_operation("FixSolids", true)
		FixSolids.risky(true)
		FixSolids.coplan(true)
		FixSolids.fixSolid(v1)
		Sketchup.active_model.commit_operation
		res=v2
	 end
	 return res
 end
  
def draw_tube pt,v,inD,extD,length
	if inD >= extD 
		UI.messagebox("Internal Diameter should be smaller than external Diameter")
		return
	end

	entities = Sketchup.active_model.entities
	tube = entities.add_group
	tube_inner = tube.entities.add_circle pt, v, inD/2 #, 180
	tube_outer = tube.entities.add_circle pt, v, extD/2 #, 180
	cross_section_face = tube.entities.add_face tube_outer
	inner_face = tube.entities.add_face tube_inner
	tube.entities.erase_entities inner_face
	cross_section_face.pushpull length, false
	return tube
end 
  