#!/usr/bin/ruby
unless $DSTD_Required
	$DSTD_Required = true
	require 'rubygems'
	require 'rvg/rvg'
	include Magick

# ----------------------------------------------------
#	Digital Signal Timing Diagram Ruby Library
# Author: Mark Fabbro
# 	Date: 2011/03/25
# ----------------------------------------------------

	class GeneralSignal
		attr_reader :name
		def tpd_at(tick, chg_time=0)
			output = 0
			if self.val_at(tick) != self.val_at(tick-1)
				output += @tpd 
				output += TimingDiagram.get_tpd(tick, @dependency) if @dependency
			end
			output -= chg_time 
			output = 0 if output < 0
			return output
		end

		def tcd_at(tick)
			output = 0
			if self.val_at(tick) != self.val_at(tick-1)
				output += TimingDiagram.get_tpd(tick, @dependency) if @dependency
			end
			return output
		end
	end

	class ClockSignal < GeneralSignal
		def initialize
			@name = 'CLOCK'
		end
	end

	class BinarySignal < GeneralSignal
		# starval			-	Integer: the binary value of this signal before the first toggle
		# toggletime 	-	Array of Integers: An array of the times (in clock ticks) when the output
		#								of this signal will toggle its value
		def initialize(config)
			@name			  = config[:label]
			@startval 	= config[:initial_value]
			@toggletime = config[:toggle_on_clk_ticks]
			@tpd			 	= config[:tpd]
			@dependency	= config[:signal_dependency] || false
		end

		def val_at(tick)
			output = (@startval + @toggletime.select{|e| e <= tick}.length) % 2 
			return output
		end
	end

	class SignalBus < GeneralSignal
		# startval 	- 	String: the label used to decribe the vector of binary signals that this 'data' represents 
		#								before the pattern commences
		# endval   	- 	String: the label used to describe the vector of binary signals that this 'data' represents
		#								after the data pattern ends.
		# data	  	- 	Array of Strings: An array of strings which represent the vector of signals. 
		#								Will be repeated  
		#								in sequence, after the startime and before the endtick.
		#	starttick	-		Integer: the time (in clock ticks) when the data commences.
		#	endtick		-		Integer: the time (in clock ticks) when the data will stop repeating.
		attr_reader :tcd
		def initialize(config)
				@name			  = config[:label]
				@startval   = config[:initial_value]
				@endval 	  = config[:final_value]
				@data 		  = config[:data_sequence]
				@starttick  = config[:commences_on_clk_tick]
				@endtick  	= config[:finishes_on_clk_tick]
				@tpd		  	= config[:tpd] || 0
				@tcd		  	= config[:tcd] || nil
				@dependency	= config[:signal_dependency] || false
		end
		def val_at(tick)
			if 		tick < @starttick
				output = @startval
			elsif @endtick and tick > @endtick
				output = @endval
			else
				sel = (tick - @starttick) % @data.length
				output = @data[sel]
			end
			return output
		end
	end


	class TimingDiagram
		def initialize(config)
			@clockperiod = config[:clockperiod] || 1000	
			@clockcycles = config[:clockcycles] + 1 
			@canvas_width = 100 + @clockcycles*@clockperiod
		end
		#	inputsigs	-	Array of *Signal Instances.
		def self.get_tpd(tick, inputsigs) 
			tpd_array = [0]
			inputsigs.each do |s|
				if s.val_at(tick) != s.val_at(tick-1)	
					tpd_array << s.tpd_at(tick)
				end
			end
			return tpd_array.max
		end

		def draw_signal(signal, d, v_height)
			v_high = 0
			chg_time = 5  #TODO somehow make this currect ish.
			v_low  = v_height
			x_curr = 0
			d.styles(:stroke=>'black', :stroke_width=>2, :stroke_linecap=>'round')
			if signal.class == ClockSignal
				@clockcycles.times do |cc|
					unless cc.eql? 0
						d.line(x_curr, v_low,   x_curr,                    v_high) 										# Draw Rising Edge
						d.line(x_curr, v_low,   x_curr,                    @canvas_height).styles(:stroke=>"black",:stroke_dasharray=>[20,8], :opacity=> 0.5, :stroke_width=>1, :fill=>'none')
					end
					d.line(x_curr, v_high, (x_curr += @clockperiod / 2), v_high)	# Draw High Clock
					d.line(x_curr, v_high, x_curr,                       v_low)											# Draw Falling Edge
					d.line(x_curr, v_low,  (x_curr += @clockperiod / 2), v_low)											# Draw Low Clock
				end
			elsif signal.class == BinarySignal
				@clockcycles.times do |cc|
					if signal.val_at(cc).zero?   then curr_val=v_low else curr_val=v_high end
					if signal.val_at(cc-1).zero? then prev_val=v_low else prev_val=v_high end
					if curr_val == prev_val
						d.line(x_curr, curr_val, (x_curr += @clockperiod), curr_val)
					else
						d.line(x_curr, prev_val, (x_curr += signal.tpd_at(cc, chg_time)), prev_val)
						d.line(x_curr, prev_val, (x_curr += chg_time), curr_val)

						endcycle = @clockperiod - signal.tpd_at(cc, chg_time) - chg_time
						d.line(x_curr, curr_val, (x_curr += endcycle), curr_val)
					end
				end
			elsif signal.class == SignalBus
				@clockcycles.times do |cc|
					if signal.val_at(cc) == signal.val_at(cc-1)							#No Change.
						x_next = x_curr + @clockperiod
						d.line(x_curr, v_high, x_next, v_high)
						d.line(x_curr, v_low,  x_next, v_low)

						if cc.eql? 0
							d.text(x_curr + 5, (v_low - v_high)/1.5){|t| t.tspan(signal.val_at(cc).to_s).styles(:font_size=>@font_size, :stroke_width=>1)}
						end
						x_curr = x_next
					else																										#Data Changed

						if signal.tcd.nil?
							d.line(x_curr, v_high, (x_curr + signal.tpd_at(cc, chg_time)), v_high)
							d.line(x_curr, v_low,  (x_curr + signal.tpd_at(cc, chg_time)), v_low)
							x_curr += signal.tpd_at(cc, chg_time)
						else
						end

						d.line(x_curr, v_high, (x_curr + chg_time), v_low)
						d.line(x_curr, v_low,  (x_curr + chg_time), v_high)
						x_curr += chg_time

						endcycle = @clockperiod - signal.tpd_at(cc, chg_time) - chg_time
						d.line(x_curr, v_high, (x_curr + endcycle), v_high)		
						d.line(x_curr, v_low,  (x_curr + endcycle), v_low)		

						d.text(x_curr + 5, (v_low - v_high)/1.5){|t| t.tspan(signal.val_at(cc).to_s).styles(:font_size=>@font_size, :stroke_width=>1)}
						x_curr += endcycle
					end
				end
			end
		end

		def generate_diagram(config)
			signals  = config[:signal_list] || []
			filename = config[:output_filename] << '.jpg'
			puts "Generating Image: ./#{filename}"
			@font_size = 20
			signal_gap	= @font_size + 20
			v_height	= @font_size + 20
			transition_width = 15
			curr_x   = 0
			curr_y   = signal_gap
			@canvas_height = 100 + signals.length * (v_height + signal_gap)
			RVG::dpi = 300
			signals.unshift(ClockSignal.new)
			pic=RVG.new((2*@clockcycles).cm,(signals.length*2).cm).viewbox(0,0,@canvas_width,@canvas_height) do |canvas|
				canvas.background_fill = 'white'

				# Determine the widest name so x-starting coordinate can be found.
				x_start = 0
				signals.each{|sig| x_start = sig.name.length if x_start < sig.name.length}
				x_start *= @font_size
				signals.each do |sig|
					# Name the Signal
					canvas.g.translate(0, curr_y) do |grp|
						# Names the Signal that will be rendered.
						grp.text(4, v_height/1.5) {|t| t.tspan(sig.name).styles(:font_size=>@font_size, :fill=>'black')}	
					end

					# Draw the Signal TODO DEAL WITH COLOURS HERE.
					canvas.g.translate(x_start, curr_y) do |grp|
						# Renders the signal.
						draw_signal(sig, grp, v_height)
					end
					curr_y += signal_gap + v_height
				end
			end
			pic.draw.write(filename)	
			puts "Finished"
		end
	end
end
