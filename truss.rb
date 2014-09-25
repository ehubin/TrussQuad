class Node
	def initialize(pt)
		@elems=[]
		@pt=pt
	end
	attr_reader :pt
	attr_accessor:tmpid
	def addElem(e)
		@elems.push(e)
	end
	
end
class Constraint
	FORCE=3
	DISPLACEMENT=1
	def initialize(type,val,dir,name)
		@value=	val
		raise ArgumentError,"incorrect type #{type}\n" if !(type == FORCE || type == DISPLACEMENT)
		@type=type
		@name=name
		@direction=dir
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
  def initialize(n1,n2,d) 
	@n1=n1
	@n2=n2
	@d=d
  end
  attr_reader :n1 
  attr_reader :n2 
  attr_reader :d 
end

class MultiElem
  def initialize(n1,n2,d,nbElem)
	if(nbElem < 2); puts "Wrong nbElem #{nbElem}\n"; end
	@nodes=[ n1]
	@elems=[]
	@d=d
	@nbElem=nbElem
	1.upto(nbElem-1) do |i|
		pt = Geom.linear_combination 1-i*1.0/nbElem,n1.pt,i*1.0/nbElem,n2.pt
		@nodes.push Node.new(pt)
		@elems.push Elem.new @nodes[i-1],@nodes[i],d
	end
	@elems.push Elem.new @nodes[nbElem-1],n2,d
	@nodes.push n2
  end
  attr_reader :d 
  attr_reader :nbElem 
  def getNodes(from=0,to=nbElem)
	return @nodes[from..to]
  end
  def getNode idx
	@nodes[idx]
  end
  
  def getElems(from=0,to=nbElem-1)
	return @elems[from..to]
  end
  def getElem idx
	@elems[idx]
  end
end

class Truss
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
			e = Elem.new(ms1.getNode(i),ms2.getNode(i),diameter)
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
			e = Elem.new(ms1.getNode(fromIdx1+i),ms2.getNode(fromIdx2+i),diameter)
			@elems.push e
			e = Elem.new(ms1.getNode(fromIdx1+i+1),ms2.getNode(fromIdx2+i),diameter)
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
	#write Truss structure as z88 file in provided folder
	def to_z88_struct(folder)
		f = File.new(File.join(folder.path,"z88structure.txt"),"w")
		f.write "3 #{@nodes.count} #{@elems.count} #{3*@nodes.count} 0 #AURORA_V2\n" 
		@nodes.count.times do |i|
			p = @nodes[i].pt
			@nodes[i].tmpid = i+1
			x= sprintf("%#.6E",p.x)
			y= sprintf("%#.6E",p.y)
			z= sprintf("%#.6E",p.z)
			f.write "#{i+1} 3 #{x} #{y} #{z}\n"
		end
		#puts "=========================>\n #{@elems}\n#{@nodes}\n"
		@elems.count.times do |i|
			e = @elems[i]
			f.write "#{i+1} 4\n#{e.n1.tmpid} #{e.n2.tmpid}\n"
		end
		f.close
	end
	
	# generate Sets for z88 (z88sets.txt) in provided folder
	def to_z88_sets(folder)
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
		fActive.write "#ELEMENTS MATERIAL 1 #{i+1} #{i+1} 2 \"Structural steel\"\n"
		
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
	
	
	# generate all z88 input files in provided folder
	def to_z88(folder)
		to_z88_struct(folder)
		to_z88_sets(folder)
	end
end