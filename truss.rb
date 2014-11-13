#scaling factor when drawing in sketchup to avoid bugs with small items

require 'fileutils'



class Node
	Pair = Struct.new(:stick,:elem) unless const_defined?(:Pair)
	def initialize(pt)
		@elems=[]
		@pt=pt
	end
	attr_reader :pt
	attr_accessor:tmpid
	attr_reader :elems
	attr_reader:connector
	def addElem(e)
		@elems.push(e)
	end
	def distanceTo(n)
		v = Geom::Vector3d.new(pt,n.pt)
		v.length
	end
	def ==(n)
		distanceTo(n) <= 0.0000001
	end
	
	
	# Draws connector in sketchup for this node using transformation for scaling.
	# this needs to be called after elements are drawn.
	def draw(tr)
		puts "start node draw #{pt}"
		
		mainElem = []
		secElem = []
		all = []
		@elems.each do |e|
			
			v = Geom::Vector3d.new
			if e.n1 == self
				v= e.n2.pt-e.n1.pt
				#puts "+"
			else
				v=e.n1.pt-e.n2.pt
				#puts "-"
			end
			#puts v
			#puts @pt
			pt1 = @pt.transform(tr)
			#puts pt1
			newStick=nil
			#connector proportion varies for big and small rods
			if e.margin1 > 0
				newStick=draw_stick pt1,v,e.d*Truss::SCALE*5,e.d*Truss::SCALE*8
				secElem.push Pair.new(newStick,e)
				all.push Pair.new(newStick,e)
			else 
				newStick=draw_stick pt1,v,e.d*Truss::SCALE*5,e.d*Truss::SCALE*3
				mainElem.push Pair.new(newStick,e)
				all.push Pair.new(newStick,e)
			end
		end
		#TODO develop the case where more than two 
		#if mainElem.count>2 
		#	puts "unsupported node"
		#	return
		#end
		#trim secondary elems with main ones
		last = nil
		mainElem.each { |m| 
			if last != nil
				last = myUnion(m.stick,last)
			else
				last = m.stick
			end
		}
		
		secElem.each do |e| 
			newOne = myTrim(last,e.stick)
			#puts "#{newOne}" 
			if newOne == nil
				puts "trim failed\n"
			else
				e.stick = newOne
			end
		end
		
		mainElem.each { |m|
			puts "==>#{m.elem.stick}  #{last}" 
			vol = myTrim( m.elem.stick,last)
			last=vol
			secElem.each do |e|
				vol = myTrim( e.elem.stick,last)
				last=vol
			end
		}
		#trim  elems with their own stick	 and aggregate
		#trim secondary elems between each other
		#secElem.each do |e|
			#e.stick = myTrim(e.elem.stick,e.stick)
			#secElem.each do |other|
			#	if other != e
			#		vol = myTrim(e.stick,other.stick)
			#		if vol == nil then puts "trim failed!!!\n" end
			#		e.stick =vol
			#	end
			#end
		#end
		secElem.each do |e|
			e.stick = myTrim(e.elem.stick,e.stick)
			if last != nil
				#puts "#{e.stick.volume} - #{last.volume}\n"
				last = myUnion(e.stick,last)
			else
				last = e.stick
			end
		end
		@connector=last
	end
end

class Constraint
	FORCE=3 unless const_defined?(:FORCE)
	DISPLACEMENT=1 unless const_defined?(:DISPLACEMENT)
	def initialize(type,val,dir,name)
		@value=	val
		raise ArgumentError,"incorrect type #{type}\n" if !(type == FORCE || type == DISPLACEMENT)
		@type=type
		@name=name
		@direction=dir.strip
		@nodes=[]
	end
	def addNode(n); @nodes.push n; end
	attr_reader :value
	attr_reader :type
	attr_reader :nodes
	attr_reader :name
	attr_reader :direction
	attr_accessor:tmpid
end
class Elem
	attr_reader:n1
	attr_reader:n2
	attr_reader:stick
  def initialize(n1,n2,d) 
	@n1=n1
	@n2=n2
	n1.addElem self
	n2.addElem self
	@d=d
	@margin1=0
	@margin2=0
	@offset1 = Geom::Vector3d.new 0,0,0
	@offset2 = Geom::Vector3d.new 0,0,0
	@me=nil
  end
  # compute margin when intersecting another element with vect and diameter
  def getMargin(vect,diam)
	v= Geom::Vector3d.new vect
	v.length = 1
	myV = getVect()
	myV.length = 1
	alpha = Math.acos( ( v%myV).abs)
	if Math.sin(alpha) < 0.000001
		return diam
	else
		return 0.5*(diam + @d*Math.cos(alpha))/Math.sin(alpha)
	end
  end
  #draws element in sketchup using Transformation for scaling
	def draw(tr)
		v = getVect()
		v.transform! tr
		vu = Geom::Vector3d.new v
		vu.length = @margin1
		p1 = @n1.pt.offset(@offset1).offset(vu).transform(tr)
		@stick = draw_stick p1,v,@d*Truss::SCALE,v.length - Truss::SCALE*(@margin1 + @margin2)
		
	end
	# return unit vector parallel to this element
	def unitVect
		v=getVect()
		v.length =1
		v
	end
	# returns actual vector corresponding to element
	def getVect
		@n2.pt.offset(@offset2) - @n1.pt.offset(@offset1)
	end
	#return element physical length
	def length
		v = getVect()
		v.length - @margin1 -@margin2
	end
	attr_reader :n1 
	attr_reader :n2 
	attr_reader :d
	attr_accessor:margin1 #distance to be removed from elem at node 1
	attr_accessor:margin2 #distance to be removed from elem at node 2
	attr_accessor:offset1 #vector to offset n1 (used for tip elements in ladder)
	attr_accessor:offset2 #vector to offset n1 (used for tip elements in ladder)
end

class MultiElem
  def initialize(n1,n2,d,nbElem)
	if(nbElem < 2); puts "Wrong nbElem #{nbElem}\n"; end
	@nodes=[ n1]
	@elems=[]
	@d=d
	1.upto(nbElem-1) do |i|
		pt = Geom.linear_combination 1-i*1.0/nbElem,n1.pt,i*1.0/nbElem,n2.pt
		@nodes.push Node.new(pt)
		@elems.push Elem.new @nodes[i-1],@nodes[i],d
	end
	@elems.push Elem.new @nodes[nbElem-1],n2,d
	@nodes.push n2
  end
  attr_reader :d 
  def nbElem
	@elems.length
  end
  def getNodes(from=0,to=nbElem)
	return @nodes[from..to]
  end
  def getNode idx
	@nodes[idx]
  end
  
  def getElems(from=0,to=nbElem-1)
	return @elems[from..to]
  end
  # returns the elem at index i. when asked for elemat nbelem still returns the last elem
  def getElem idx
	if idx == @elems.length; idx = @elems.length-1; end
	@elems[idx]
  end
  def addStick diam,length,t
	lastElem = @elems[@elems.length-1]
	v = lastElem.unitVect
	v.length = length
	pt =  lastElem.n2.pt.offset v
	newElem = t.addStick diam,lastElem.n2.pt,pt
	newNode = Node.new(pt)
	@nodes.push newElem.n2
	@elems.push newElem
	newElem
  end
end

class Truss
	SCALE=10000 unless const_defined?(:SCALE)
	Z88_BIN="D:/Programs/Z88AuroraV2/win/bin" unless const_defined?(:Z88_BIN)
	def initialize
		@elems = [] 
		@nodes = []
		@constraints = []
	end
	
	def addConstraint (type,val,dir,name)
		c = Constraint.new(type,val,dir,name)
		@constraints.push c
		c
	end
	
	# pt1 can be Node or Point3d
	# pt2 can be a node or point or an array with vector+length
	def addStick(diameter,pt1,pt2)
		#puts pt2
		if (pt1.is_a?Geom::Point3d); pt1 = getNode(pt1); end
		if(!(pt2.is_a?(Geom::Point3d )|| pt2.is_a?(Node))) 
			v=pt2[0].clone
			v.length=pt2[1]
			pt2 = pt1.offset v
		end
		if(pt2.is_a?Geom::Point3d); pt2 = getNode(pt2); end
		e = Elem.new(pt1,pt2,diameter)
		@elems.push e
		return e
	end
	
	# pt2 can be a point or an array with vector+length
	def addMultiStick(diameter,pt1,nbElem,pt2)
		if(!pt2.is_a?(Geom::Point3d))
			v=pt2[0].clone
			v.length=pt2[1]
			pt2 = pt1.offset v
		end
		e = MultiElem.new(getNode(pt1),getNode(pt2),diameter,nbElem)
		@elems.concat(e.getElems)
		@nodes.concat( e.getNodes(1,e.nbElem-1))
		return e
	end
	
	
	# connect two multisticks using a ladder-like pattern with diameter sticks
	def connectLadder(ms1,ms2,diameter,fromIdx,toIdx)
		if (!ms1.is_a?(MultiElem) || !ms2.is_a?(MultiElem) ) 
			puts "connectLadder() can only connect two MultiSticks\n"
			return
		end
		if(fromIdx < 0 || fromIdx > toIdx)
			puts "connectLadder() invalid fromIdx #{fromIdx}\n"
			return
		end
		if(toIdx > ms1.nbElem || toIdx > ms2.nbElem)
			puts "connectLadder() invalid toIdx #{toIdx}\n"
			return
		end
		
		fromIdx.upto(toIdx) do |i|
		    #puts "===>#{i}\n"
			e = Elem.new(ms1.getNode(i),ms2.getNode(i),diameter)
			v1 = (ms1.getElem(i)).unitVect
			v2 = (ms2.getElem(i)).unitVect
			e.margin1 = e.getMargin(v1,ms1.d)
			e.margin2 = e.getMargin(v2,ms2.d)
			# tip element should be offset 
			if(i == ms1.nbElem)
				v1.length = 2*diameter
				v1.reverse!
				v2.length = 2*diameter
				v2.reverse!
				e.offset1 = v1
				e.offset2 = v2
			end
			@elems.push e
		end
	end
	
	# connect two multisticks using a triangular-like pattern with diameter sticks
	# ms1 will support triangle base, ms2 will support triangle tips
	def connectTriangle(ms1,fromIdx1,ms2,fromIdx2,diameter,nbTriangles)
		if (!ms1.is_a?(MultiElem) || !ms2.is_a?(MultiElem) ) 
			puts "connectTriangle() can only connect two MultiSticks\n"
			return
		end
		if(fromIdx1 < 0 || fromIdx2 <0)
			puts "connectTriangle() invalid fromIdx #{fromIdx1} or #{fromIdx2}\n"
			return
		end
		if(fromIdx1+nbTriangles > ms1.nbElem || fromIdx2+nbTriangles-1 > ms2.nbElem)
			puts "connectTriangle() too many triangles #{nbTriangles}\n"
			return
		end
		
		nbTriangles.times do |i|
			#puts "+++>#{i}\n"
			e = Elem.new(ms1.getNode(fromIdx1+i),ms2.getNode(fromIdx2+i),diameter)
			e.margin1 = e.getMargin((ms1.getElem(fromIdx1+i)).unitVect,ms1.d)
			e.margin2 = e.getMargin((ms2.getElem(fromIdx2+i)).unitVect,ms2.d)
			@elems.push e
			e = Elem.new(ms1.getNode(fromIdx1+i+1),ms2.getNode(fromIdx2+i),diameter)
			e.margin1 = e.getMargin((ms1.getElem(fromIdx1+i+1)).unitVect,ms1.d)
			e.margin2 = e.getMargin((ms2.getElem(fromIdx2+i)).unitVect,ms2.d)
			@elems.push e
			
		end
		#puts "connectTriangle() ok"
	end
	
	
	def getNode pt
		idx = @nodes.index { |n| n.pt == pt }
		if idx == nil
			n1= Node.new pt
			@nodes.push n1
			return n1
		else
			return @nodes[idx]
		end
	end
	
	def to_s
		"#{@elems} ;; #{@nodes}"
	end
	
	# returns a hash with { diameter => [elem_idx,...]}
	def getTypes
		types = Hash.new
		@elems.count.times do |i|
			d = @elems[i].d.to_f.to_s
			if types.has_key?(d)
				types[d].push(i+1)
			else
				types[d]=[i+1]
			end
		end
		return types
	end
	# returns a hash with { diameter => total length}
	def getLength
		length = Hash.new
		@elems.count.times do |i|
			d = @elems[i].d.to_m
			if length.has_key?(d)
				length[d] += @elems[i].length.to_m
			else
				length[d]= @elems[i].length.to_m
			end
		end
		return length
	end
	# returns a hash with { diameter => total length}
	def getConnectorVolume
		vol = 0
		@nodes.each do |n|
			if n.connector == nil
				puts "Missing connector on node at #n.pt}\n"
			else
				vol +=n.connector.volume
			end
		end
		vol
	end
	#write Truss structure as z88 file in provided folder
	def to_z88_struct(folder)
		f = File.new(File.join(folder.path,"z88structure.txt"),"w")
		f.write "3 #{@nodes.count} #{@elems.count} #{3*@nodes.count} 0 #AURORA_V2\n"
		@nodes.count.times do |i|
			p = @nodes[i].pt
			@nodes[i].tmpid = i+1
			x= sprintf("%#.6E",p.x)
			y= sprintf("%#.6E",p.y)
			z= sprintf(" %#.6E",p.z)
			f.write "#{i+1} 3 #{x} #{y} #{z}\n"
		end
		#puts "=========================>\n #{@elems}\n#{@nodes}\n"
		@elems.count.times do |i|
			e = @elems[i]
			f.write "#{i+1} 4\n#{e.n1.tmpid} #{e.n2.tmpid}\n"
		end
		f.close
	end
	
	# generate Sets for z88 (z88sets.txt) in provided folder,copies all *.ref files in refFolder to folder
	def to_z88_sets(folder,refFolder)
		f = File.new(File.join(folder.path,"z88sets.txt"),"w")
		fActive = File.new(File.join(folder.path,"z88setsactive.txt"),"w")
		# get all types of elements
		types = getTypes
		#puts "#{types}\n"
		count = 1+types.count+@constraints.count
		f.write "#{count}\n"
		fActive.write "#{count}\n"
		#write element sets by diameters
		i=0
		types.each do |d,e|
			i=i+1
			diam = sprintf("%#.6E",d)
			fActive.write "#ELEMENTS ELEMENTGEO 1 #{i} #{i} 1 0.000000E+000 0.000000E+000 0.000000E+000 0.000000E+000 #{diam} 0.000000E+000 0.000000E+000 0 0.000000E+000 0.000000E+000 0.000000E+000 0.000000E+000 \"ElementSet#{i}\"\n"
			f.write "#ELEMENTS ELEMENTGEO #{i} #{e.count} \"ElementSet#{i}\"\n"
			j=0
			e.each do |elem|
				f.write "#{elem}\t"
				j=j+1
				f.write "\n" if j%10 ==0
			end
			f.write "\n" if j%10 !=0
		end
		f.write "#ELEMENTS MATERIAL #{i+1} #{@elems.count} \"MatSet1\"\n"
		@elems.count.times do |k|
			f.write "#{k+1}\t"
			f.write "\n" if ((k+1)%10 ==0 ) && (k != @elems.count-1)
		end
		f.write "\n"
		fActive.write "#ELEMENTS MATERIAL 1 #{i+1} #{i+1} 52 \"Carbon Fiber\"\n"
		@constraints.count.times do |k|
			i=i+1
			f.write "#NODES CONSTRAINT #{i+1} #{@constraints[k].nodes.count} \"#{@constraints[k].name}\"\n"
			@constraints[k].nodes.count.times do |j|
				f.write "#{@constraints[k].nodes[j].tmpid}\t"
				f.write "\n" if (j+1)%10 ==0
			end
			f.write "\n"
			fActive.write "#NODES CONSTRAINT 1 #{i+1} #{i+1} 11 #{@constraints[k].direction} #{@constraints[k].type} #{@constraints[k].value} \"#{@constraints[k].name}\"\n"
		end
		
		f.close
		fActive.close
		
	end
	
	#draw the truss in sketchup
	def draw
		tr = Geom::Transformation.new(SCALE)
		invTr = Geom::Transformation.new(1.0/SCALE)
		# draw sticks for elems first
		@elems.each do |e|
			e.draw(tr)
		end
		#then draw connectors at each node
		@nodes.each do |n|
			n.draw(tr)
		end
		entities = Sketchup.active_model.entities
		entities.each do |e|
			entities.transform_entities(invTr, e)
		end
	end
	# generate all z88 input files in provided folder
	def to_z88(folder,refFolder)
		to_z88_struct(folder)
		to_z88_sets(folder,refFolder)
		# copy reference files into the folder
		Dir.foreach(refFolder.path) do |f|
			if File.extname(f) == ".ref"
				#puts f
				FileUtils.cp(File.join(refFolder.path,f),File.join(folder.path,File.basename(f,".ref")))
			end
		end
		#convert the data to be able to run the solver
		Dir.chdir(Z88_BIN)
		puts "Data conversion returns #{system("z88ag2ri.exe 2 1 #{folder.path}")}"
		
		#run the solver
		Dir.chdir(folder.path)
		puts "z88r test run returns #{system("#{File.join(Z88_BIN,"z88r.exe")} -t -sorcg")}"
		puts "z88r real run returns #{system("#{File.join(Z88_BIN,"z88r.exe")} -c -sorcg")}"
		
		#run postprocess to be able to see the result in the UI
		puts "Post processor returns #{system(File.join(Z88_BIN,"z88ro2ag.exe"))}"
		
		#parse results 
		o3_line = /^element # =\s+(?<ElNo>\d+).*SIG =\s+(?<Const>\S+)/
		o2_line = /^\s+(?<ElNo>\d+)\s+(?<x>[+-]\S+)\s+(?<y>[+-]\S+)\s+(?<z>[+-]\S+)/
			
		

		File.new(File.join(folder.path,"z88o3.txt"),"r").each_line do |line|
			l = line.match(o3_line)
			if(l != nil )
				puts "el# #{l[:ElNo]} constraint= #{l[:Const]}"
			end
		end
		File.new(File.join(folder.path,"z88o2.txt"),"r").each_line do |line|
			l = line.match(o2_line)
			if(l != nil )
				puts "node# #{l[:ElNo]} dipls x= #{l[:x]} dipls y= #{l[:y]} dipls z= #{l[:x]}"
			end
		end
	end
end
