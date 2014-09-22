class Node
	def initialize(pt)
		@elems=[]
		@pt=pt
	end
	def pt
		@pt
	end
	def tmpid=(id) 
		@tmpid=id
	end
	def tmpid
		@tmpid
	end
	def addElem(e)
		@elems.push(e)
	end
	
end

class Elem
  def initialize(n1,n2,d) 
	@n1=n1
	@n2=n2
	@d=d
  end
  def n1 
	@n1 
	end
  def n2 
	@n2
	end
	def d
		@d
	end
end

class Truss
	def initialize
		@elems = [] 
		@nodes = []
	end
	
	def addStick(diameter,pt1,pt2)
		e = Elem.new(getNode(pt1),getNode(pt2),diameter)
		@elems.push e
		return e
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
			d = @elems[i].d.to_s
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
		puts "toto"
		types = getTypes
		puts "#{types}\n"
		f.write "#{1+types.count}\n"
		fActive.write "#{1+types.count}\n"
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
		f.close
		fActive.close
	end
	
	
	# generate all z88 input files in provided folder
	def to_z88(folder)
		to_z88_struct(folder)
		to_z88_sets(folder)
	end
end
