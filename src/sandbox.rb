#
# Multiverse - p2p online virtual community
# Copyright (C) 2007  Nathan C. Matthews <lowentropy@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#


$: << File.dirname(__FILE__)

require 'untrace'

# A sandbox object allows code blocks to run in a
# clean environment; if the blocks have $SAFE = 4,
# they are effectively cut off from the rest of
# the system, while the sandbox itself is tainted.
# Makes use of the instance_exec extension.
class Sandbox

	include Untrace

  attr_reader :_delegates
  
	# set up empty environment and taint ourself (wow, that sounds naughty)
	def initialize
		@_delegates = {}
		@_root_delegate = nil
		self.taint
	end

	# call code within the sandboxed environment
	def sandbox(&block)
		untraced(2) do
			instance_eval &block
		end
	end

	# retrieve a sandbox-local variable
	def [](key)
		eval "@#{key}"
	end

	# set a sandbox-local variable
	def []=(key, value)
		eval "@#{key} = value"
	end

	# delegate function calls of a given name to be run
	# (unprotected!) on the given object. 1) ONLY USE THIS IF
	# YOU KNOW WHAT YOU ARE DOING. 2) DON'T KID YOURSELF, YOU
	# HAVE NO CLUE WHAT YOU'RE DOING. 3) fnord
	def delegate(name, object)
		if name
			@_delegates[name.to_sym] = object
		else
			@_root_delegate = object
		end
	end

	# rename entries in a stack trace
	def rename_backtrace(error, name, from="`add_script'")
		this = error.backtrace.find {|line| /#{from}/ =~ line}
		index = error.backtrace.index this
		error.backtrace[index].gsub! /`.*'/, "`#{name}'"
	end

	# FIXME: at some point in the future, we should unbind the
	# delegate's methods and call them on the sandbox instance,
	# instead of trusting that the delegator is conscientious
	# about access.
	def method_missing(id, *args, &block)
		untraced(2) do
			name = id.id2name.to_sym
			if @_delegates[name]
				@_delegates[name].send name, *args, &block
			elsif @_root_delegate
				@_root_delegate.send name, *args, &block
			else
				super
			end
		end
	end

end
