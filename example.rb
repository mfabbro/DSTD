#!/usr/bin/ruby
require 'dstd' # Require the Digital Signal Timing Diagram Library.

#
# Running this script generates the exoutput.jpg file
# NOTE: This is running on top of Rmagick. If a different
#	output type is wanted edit the dstd.rb line: 


clockperiod = 150
clockcycles = 9
tpd = clockperiod / 8
output_filename = 'exoutput'

set =  BinarySignal.new(:label                 => 'SET',
                        :initial_value         => 0,
                        :toggle_on_clk_ticks   => [1,2],
                        :tpd                   => tpd,
                        :signal_dependency     => [])

count =   SignalBus.new(:label                 => 'COUNT',
                        :initial_value         => '  0',
                        :final_value           => '  0',
                        :data_sequence         => ['  4', '  4', '  4', '  3', '  2', '  1'],
                        :commences_on_clk_tick => 2,
                        :finishes_on_clk_tick  => 2 + 5,
                        :tpd                   => tpd,
                        :signal_dependency     => [])

dec =  BinarySignal.new(:label                 => 'DEC',
                        :initial_value         => 0,
                        :toggle_on_clk_ticks   => [4, 8],
                        :tpd                   => tpd,
                        :signal_dependency     => [])

zero = BinarySignal.new(:label                 => 'ZERO',
                        :initial_value         => 1,
                        :toggle_on_clk_ticks   => [2, 8],
                        :tpd                   => tpd,
                        :signal_dependency     => [count])


 td = TimingDiagram.new(:clockcycles=>clockcycles, :clockperiod=>clockperiod)
 td.generate_diagram(:signal_list => [set, count, dec, zero], :output_filename => output_filename)

