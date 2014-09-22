# First we pull in the standard API hooks.
require 'sketchup.rb'
require 'fixSolid15'
require 'truss.rb'

# Show the Ruby Console at startup so we can
# see any programming errors we may make.
SKETCHUP_CONSOLE.show

# Add a menu item to launch our plugin.
if( !($menu_for_copter == "created") )
	$menu_for_copter = "created";
	UI.menu("Plugins").add_item("Draw copter") {
	  draw_copter
	}
	UI.menu("Plugins").add_item("Create 3D print") {
	  create_3dprint_grid
	}
	UI.menu("Plugins").add_item("Create Z88") {
	  create_z88
	}
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


def draw_stick pt,v,diam,length,type=nil,grp=nil
	if(grp==nil)
		grp = Sketchup.active_model.entities.add_group
	end
	circle = grp.entities.add_circle pt, v, diam/2 #, 180
	cross_section_face = grp.entities.add_face circle
	cross_section_face.pushpull length, false
	grp.set_attribute("rod","d",diam)
	grp.set_attribute("rod","type",type)
	grp.set_attribute("rod","l",length)
	grp.set_attribute("rod","sx",pt.x)
	grp.set_attribute("rod","sy",pt.y)
	grp.set_attribute("rod","sz",pt.z)
	grp.set_attribute("rod","ex",pt.x+length*v.x/v.length)
	grp.set_attribute("rod","ey",pt.y+length*v.y/v.length)
	grp.set_attribute("rod","ez",pt.z+length*v.z/v.length)
	return grp
end

def report_length
	res=Hash.new(0)
	Sketchup.active_model.entities.each {|elem|
	  d=elem.get_attribute( "rod","d")
	  if (d)
		l= elem.get_attribute( "rod","l")
		res[d] = l+res[d]
	  end 
	}
	res.keys.each do |d|
		puts "#{d*25.4/1000}:#{res[d]*25.4/1000}"
	end
end

def create_z88
	z88_path="D:\\ehubin\\Documents\\Dev\\z88\\"
	newDir = Dir.new(File.join(z88_path,"test_dir"))
	theTruss = Truss.new
	pt1 = [0,0,0]
	pt2 = [1,0,0]
	pt3 = [0,1,0]
	pt4 = [0,1,1]
	pt5 = [1,1,0]
	pt6 = [1,1,1]
	
	theTruss.addStick 3,pt1,pt3
	theTruss.addStick 3,pt1,pt4
	theTruss.addStick 3,pt1,pt5
	theTruss.addStick 4,pt1,pt6
	theTruss.addStick 4,pt2,pt3
	theTruss.addStick 4,pt2,pt4
	theTruss.addStick 4,pt2,pt5
	theTruss.addStick 5,pt2,pt6
	theTruss.addStick 5,pt3,pt4
	theTruss.addStick 3,pt3,pt5
	theTruss.addStick 4,pt1,pt2
	# theTruss.addStick 2,pt3,pt6
	 theTruss.addStick 2,pt5,pt6
	# theTruss.addStick 2,pt4,pt6
	theTruss.to_z88 newDir
	
	# Sketchup.active_model.entities.each {|elem|
	  # t=elem.get_attribute( "rod","type")
	  # if (t=="truss")
		# startId=(elem.get_attribute( "rod","sx")*2.54).floor.to_s+"|"+(elem.get_attribute( "rod","sy")*2.54).floor.to_s+"|"+(elem.get_attribute( "rod","sz")*2.54).floor.to_s
		# puts ">>#{startId}<<"
	  # end 
	# }
	
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
# compute the line on a stick that is in the direction of otherpt
def compute_line pt,v,diam,length,otherpt
	
	v.length = length
	stop=pt.offset v
	v.normalize!
	u = Geom::Vector3d.new otherpt[0]-pt[0],otherpt[1]-pt[1],otherpt[2]-pt[2]
	coef = u.dot v
	k=0
	
	kk=0
	for i in 0..2 
	  tmp=u[i]-v[i]*coef
	  kk += tmp*tmp
	end
	k= Math.sqrt(1/kk)
	l=-k*coef
	x= Geom::Vector3d.linear_combination l*diam,v,k*diam,u
	
	return [ pt.offset(x), stop.offset(x) ]
end

def draw_truss line1,line2,nbTruss,diam,offset
(nbTruss-1).times do |i|
		sp=Geom.linear_combination (i+0.5)/(nbTruss-1.0),line1[0],1-(i+0.5)/(nbTruss-1.0),line1[1]
		ep = []
		ep[0]=Geom.linear_combination i/(nbTruss-1.0),line2[0],1-i/(nbTruss-1.0),line2[1]
		ep[1]=Geom.linear_combination (i+1)/(nbTruss-1.0),line2[0],1-(i+1)/(nbTruss-1.0),line2[1]
		2.times do |j|
			spv = Geom::Vector3d.new sp.to_a
			epv = Geom::Vector3d.new ep[j].to_a
			de = epv-spv
			de.length = offset
			spt=sp.offset de
			de.reverse!
			_l = spt.distance ep[j].offset de
			dir= Geom::Vector3d.new(ep[j][0]-spt[0],ep[j][1]-spt[1],ep[j][2]-spt[2])
			draw_stick spt, dir,diam,_l,"truss"
			
		end
	end
end

def draw_ladder line1,line2,nbTruss,diam,offset
	nbTruss.times do |i|
		sp = Geom.linear_combination i/(nbTruss-1.0),line1[0],1-i/(nbTruss-1.0),line1[1]
		ep = Geom.linear_combination i/(nbTruss-1.0),line2[0],1-i/(nbTruss-1.0),line2[1]
		
		spv = Geom::Vector3d.new sp.to_a
		epv = Geom::Vector3d.new ep.to_a
		de = epv-spv
		de.length = offset
		sp.offset! de
		de.reverse!
		ep.offset! de
		
		_l = sp.distance ep
		draw_stick sp, Geom::Vector3d.new(ep[0]-sp[0],ep[1]-sp[1],ep[2]-sp[2]),diam,_l,"truss"
	end
end

def draw_arm angle,dist
   rot = Geom::Transformation.rotation [0,0,0], [0,0,1], angle*(Math::PI)/180
   w= 80.m
   h= 90.m
   r = 1.m
   l = 300.m
   tip = 20.m
   tiph = 30.m
   nbTruss=5
   
   pt =[]
   pt[1] = Geom::Point3d.new dist,w/2,0
   v1 = Geom::Vector3d.new l,-(w-tip)/2,0
   pt[2] = Geom::Point3d.new dist,-w/2,0
   v2 = Geom::Vector3d.new l,(w-tip)/2,0
   pt[3] = Geom::Point3d.new dist,0,-h
   v3 = Geom::Vector3d.new l,0,(h-tiph)
   
   pt[1].transform! rot
   pt[2].transform! rot
   pt[3].transform! rot
   v1.transform! rot
   v2.transform! rot
   v3.transform! rot
   
   stick1 = draw_stick pt[1],v1,r,Math.sqrt(l*l+(w-tip)*(w-tip)/4),"truss"
   stick2 = draw_stick pt[2],v2,r,Math.sqrt(l*l+(w-tip)*(w-tip)/4),"truss"
   stick3 = draw_stick( pt[3],v3,r,1.1*Math.sqrt(l*l+(h-tiph)*(h-tiph))*(1-1.0/(2*(nbTruss-1))),"truss")
   
    stop3 = pt[3].offset v3
	stop1 =  pt[1].offset v1
	stop2 =  pt[2].offset v2
	line3 = [pt[3],stop3]
	line1 = [pt[1],stop1]
	line2 = [pt[2],stop2]
   
	draw_ladder line1,line2,nbTruss,0.5.m,1.9.m
	draw_truss line3,line1,nbTruss,0.5.m,1.9.m
	draw_truss line3,line2,nbTruss,0.5.m,1.9.m
	
	# lower joins
	entities = Sketchup.active_model.entities
	joins =[]
	v3.length = 6.m
	(nbTruss-1).times do |i|
	    joins[i] = entities.add_group
		sp=Geom.linear_combination (i+0.5)/(nbTruss-1.0),line3[0],1-(i+0.5)/(nbTruss-1.0),line3[1]
		ep = []
		ep[0]=Geom.linear_combination i/(nbTruss-1.0),line2[0],1-i/(nbTruss-1.0),line2[1]
		ep[1]=Geom.linear_combination (i+1)/(nbTruss-1.0),line2[0],1-(i+1)/(nbTruss-1.0),line2[1]
		ep[2]=Geom.linear_combination i/(nbTruss-1.0),line1[0],1-i/(nbTruss-1.0),line1[1]
		ep[3]=Geom.linear_combination (i+1)/(nbTruss-1.0),line1[0],1-(i+1)/(nbTruss-1.0),line1[1]
		
		tmppt= sp.offset v3
		joins[i] = draw_stick tmppt,v3.reverse, 2.4.m,12.m #,joins[i]
		joins[i] = myTrim(stick3,joins[i])
		tmps=[]
		tmps2=[]
		4.times do |j|
			tmps[j] = draw_stick sp, Geom::Vector3d.new(sp,ep[j]) ,1.9.m,5.m #,joins[i]
			tmps[j] = joins[i].trim(tmps[j])
			tmps[j] = stick3.trim(tmps[j])

			tmps2[j]= draw_stick sp, Geom::Vector3d.new(sp,ep[j]) ,0.5.m,6.m  #,joins[i]
			
			
			#joins[i] = res
			#joins[i].entities.each {|et| 
			#	if(et.is_a? Sketchup::Edge )
					#joins[i].entities.add_edges et.curve
			#	end
			#	if (et.is_a? Sketchup::Face)
			#		face= joins[i].entities.add_face et.edges
			#		if (face)
			#			puts face
			#		else
			#			puts "Failure"
			#		end
			#	end
			#}
		end
		4.times do |j|
			joins[i]=tmps2[j].trim(joins[i])
			4.times do |k|
				tmps[j]=myTrim(tmps2[k],tmps[j])
			end
			joins[i]=myUnion(joins[i],tmps[j])
		end
		4.times do |j|
			Sketchup.active_model.entities.erase_entities(tmps2[j])
		end
		#define linking locations 
		d1 = v3 * [0,0,1]
		d1.length = 1.7.m
		d2 = v3* [0,0,-1]
		d2.length = 1.7.m
		p1 = sp.offset d1
		p2 = sp.offset d2
		joins[i].set_attribute("link","x1",p1.x)
		joins[i].set_attribute("link","y1",p1.y)
		joins[i].set_attribute("link","z1",p1.z)
		joins[i].set_attribute("link","x2",p2.x)
		joins[i].set_attribute("link","y2",p2.y)
		joins[i].set_attribute("link","z2",p2.z)
	end
	
	# top joins
	v = []
	v[0]=v1
	v[0].length = 4.m
	v[1]=v2
	v[1].length= 4.m
	st=[]
	st[0]=stick1
	st[1]=stick2
	sp=[]
	tjoin=[]
	tjoin[0] = []
	tjoin[1] = []
	nbTruss.times do |i|
		sp =[]
		
		sp[0]=Geom.linear_combination i/(nbTruss-1.0),line1[0],1-i/(nbTruss-1.0),line1[1]
		sp[1]=Geom.linear_combination i/(nbTruss-1.0),line2[0],1-i/(nbTruss-1.0),line2[1]
		sp[2]=sp[0]	
		2.times do |j|
			tmppt= sp[j].offset v[j]
			tjoin[j][i]=draw_stick tmppt,v[j].reverse, 2.4.m,8.m
			tjoin[j][i]=myTrim(st[j],tjoin[j][i])
			stk = draw_tube sp[j],Geom::Vector3d.new(sp[j],sp[j+1]),0.5.m,1.9.m,5.m
			stk = myTrim(st[j],stk)
			tjoin[j][i] = myUnion(tjoin[j][i],stk)
			if(i>0)
				ep = Geom.linear_combination (i-0.5)/(nbTruss-1.0),line3[0],1-(i-0.5)/(nbTruss-1.0),line3[1]
				stk = draw_tube sp[j],Geom::Vector3d.new(sp[j],ep),0.5.m,1.9.m,5.m
				#stk = st[j].trim(stk)
				tjoin[j][i] = myUnion(tjoin[j][i],stk)
				tjoin[j][i] = myTrim(st[j],tjoin[j][i])
			end
			if(i<nbTruss-1)
				ep = Geom.linear_combination (i+0.5)/(nbTruss-1.0),line3[0],1-(i+0.5)/(nbTruss-1.0),line3[1]
				stk = draw_tube sp[j],Geom::Vector3d.new(sp[j],ep),0.5.m,1.9.m,5.m
				#stk = st[j].trim(stk)
				tjoin[j][i] = myUnion(tjoin[j][i],stk)
				tjoin[j][i] = myTrim(st[j],tjoin[j][i])
			end
			#define linking locations
			if(j==0)
				dir = (pt[2] - pt[1]) + (pt[3] - pt[1])
			else
				dir = (pt[1] - pt[2]) + (pt[3] - pt[2])
			end
			d1 = v[j] * dir
			d1.length = 1.7.m
			d2 = d1.reverse
			d2.length = 1.7.m
			p1 = sp[j].offset d1
			p2 = sp[j].offset d2
			puts "==>#{tjoin[j][i]}"
			if(tjoin[j][i])
				tjoin[j][i].set_attribute("link","x1",p1.x)
				tjoin[j][i].set_attribute("link","y1",p1.y)
				tjoin[j][i].set_attribute("link","z1",p1.z)
				tjoin[j][i].set_attribute("link","x2",p2.x)
				tjoin[j][i].set_attribute("link","y2",p2.y)
				tjoin[j][i].set_attribute("link","z2",p2.z)
			else
				puts "corrupted join:#{tjoin[j][i]}"
			end
		end
	end
end

def draw_copter
 

  Sketchup.active_model.options["UnitsOptions"]["LengthUnit"]=2  
  Sketchup.active_model.entities.clear!

  draw_arm 0,40.m
  #draw_arm 90,40.m
  #draw_arm 180,40.m
  #draw_arm 270,40.m  
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
  
  
  
