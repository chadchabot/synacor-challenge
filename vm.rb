#!/bin/ruby

class Registers
  def initialize()
    @registers = Array.new(8, 0)
  end

  def get(idx)
    #puts "getting the value of R#{idx} which is #{@registers[idx]}"
    idx = idx % 32768
    @registers[idx]
  end

  def set(idx, value)
    #puts "setting value of R#{idx} = #{value}"
    idx = idx % 32768
    @registers[idx] = value
  end

  def dump()
    delim = "************************************************************"
    out = "\t#{delim}\n"
    @registers.each_with_index do |v, idx|
      out += "\t r#{idx} => #{v}"
      out += "\n" if idx % 4 == 3
    end
    out += "\t#{delim}\n"
    puts out
  end
end

class Stack
  def initialize()
    @stack = Array.new()
  end

  def push(value)
    @stack.push value
  end

  def pop()
    @stack.pop()
  end

  def empty?()
    @stack.length == 0
  end

  def size()
    @stack.length
  end

  def dump()
    puts @stack
  end
end

class Memory
  def initialize(registers)
    @memory = Array.new(2**15, nil)
    @registers = registers
  end

  def get
    @memory.select {|m| m != nil}
  end

  def set_range(values, range_start, range_end)
    @memory[range_start, range_end] = values
  end

  def get_item(address)
    @memory[address]
  end

  def set_item(address, value)
    if address.between? 0, 32767
      #is a literal value, either integer or opcode
      @memory[address] = value % 32768
    elsif address.between? 32768, 32775
      #is a register
      r_num = address - 32768
      @registers.set r_num, value
    else
      raise "invalid value"
    end
  end

  def read(start, length)
    @memory[start, length]
  end

  def size()
    @memory.size
  end

  def to_s
    attributes.each_with_object("") do |attribute, result|
      result << "#{attribute[1].to_s}"
    end
  end
end

class VM
  def initialize(trace = nil, dump = nil)
    @trace = trace
    @dump  = dump

    @registers = Registers.new()
    @stack = Stack.new()
    @memory = Memory.new(@registers)
    @pc = 0

    @args_req = 0
    @args_expected = 3
  end

  def load(program)
    program = program.split(",")
    @memory.set_range program, 0, program.size
    @mem_size = program.size
  end

  def execute()
    step while @pc < @mem_size
  end

  #step should increment the program counter
  #and actually run the operation on the stack
  def step()
    dump_registers() if @debug
    operation, args = fetch_instruction @pc
    @pc += 1 + operation[:numArgs]
    args = args.map {|e| e.to_i}
    self.send "op_#{operation[:name]}".to_sym, *args
  end

  #figure out which opcode is going to be used, and then load the arguments for
  #that opcode
  def fetch_instruction(address)
    opcode = @memory.get_item(address).to_i
    op = get_operation(opcode)
    args = @memory.read(address+1, op[:numArgs])
    return op, args
  end

  def dump_registers()
    @registers.dump()
  end

  def dump_stack()
    @stack.dump()
  end

  def dump_mem()
    puts memory
  end

  def value(value)
    if value.between? 0, 32767
      #is a literal value, either integer or opcode
      value
    elsif value.between? 32768, 32775
      #is a register
      r_num = value - 32768
      @registers.get r_num
    else
      raise "invalid value"
    end
  end

  #Operations
  def op_halt()
    puts "exiting program"
    exit
  end

  def op_set(register, value)
    @register.set register, value(value)
  end

  def op_push(value)
    @stack.push value(value)
  end

  def op_pop(dest_address)
    @memory.set dest_address, @stack.pop
  end

  def ea(dest_address, a, b)
    if value(a) == value(b)
      @memory.set dest_address, 1
    else
      @memory.set dest_address, 0
    end
  end

  def op_add(destination, v1, v2)
    v1 = value(v1.to_i)
    v2 = value(v2.to_i)
    sum = v1 + v2
    sum %= 32768
    @registers.set destination[1].to_i, sum
  end

  def op_out(address)
    value = value(address)
    puts value
  end

  def op_noop()
    return
  end

  def get_operation(opcode)
    #returns opcode {name, num args}
    case opcode.to_i
      when 0  then {name: 'halt', numArgs: 0}
      when 1  then {name: 'set',  numArgs: 2}
      when 2  then {name: 'push', numArgs: 1}
      when 3  then {name: 'pop',  numArgs: 1}
      when 4  then {name: 'eq',   numArgs: 3}
      when 5  then {name: 'gt',   numArgs: 3}
      when 6  then {name: 'jmp',  numArgs: 1}
      when 7  then {name: 'jt',   numargs: 2}
      when 8  then {name: 'jf',   numArgs: 2}
      when 9  then {name: 'add',  numArgs: 3}
      when 10 then {name: 'mult', numArgs: 3}
      when 11 then {name: 'mod',  numArgs: 3}
      when 12 then {name: 'and',  numArgs: 3}
      when 13 then {name: 'or',   numArgs: 3}
      when 14 then {name: 'not',  numArgs: 3}
      when 15 then {name: 'rmem', numArgs: 2}
      when 16 then {name: 'wmem', numArgs: 2}
      when 17 then {name: 'call', numArgs: 1}
      when 18 then {name: 'ret',  numArgs: 0}
      when 19 then {name: 'out',  numArgs: 1}
      when 20 then {name: 'in',   numArgs: 1}
      when 11 then {name: 'noop', numArgs: 0}
    end
  end
end

#store in R0 the sum of R1 & 4, then print out the contents of R0
puts "Initial test"
test1 = "9, 32768, 32769, 4, 19, 32768"

vm = VM.new(false,false)
vm.load test1
vm.execute

puts "*****************************************"
puts "Trying challenge"

program = File.open('challenge.bin', "rb").read
puts program
vm.load program
vm.execute
