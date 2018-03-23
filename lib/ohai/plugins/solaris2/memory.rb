#
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

Ohai.plugin(:Memory) do
  provides "memory"

  collect_data(:solaris2) do
    memory Mash.new
    memory[:swap] = Mash.new
    meminfo = shell_out("prtconf | grep Memory").stdout
    memory[:total] = "#{meminfo.split[2].to_i * 1024}kB"

    # There needs to be a distinction between Physical (Disk Backed) and 
    # Virtual (RAM + Disk Backed) swap on Solaris.
    # 'swap -s' deals entirely in Virtual Swap, leaving out all details regarding
    # how much Physical Swap has been provided to the system, or whether it has
    # been reserved against/used.
    # The crucial thing to understand about Solaris Virtual Swap is:
    # - Physical (Disk Backed) swap is reserved against first, then RAM Backed Swap
    # The following diagram shows the interrelationships between virtual and
    # physical Solaris swap:
    #
    #  +--> +-----------------+ <--------+
    #  |    |RAM Backed Swap  |   RAM Backed swap
    #  |    |(variable)       |   fluctuates with the amount
    #  |    |                 |   of free RAM available in a
    #  |    |                 |   host, so Total Virtual Swap
    #  |    |                 |   is expected to vary over time,
    # Total |                 |   sometimes wildly, based on
    # Virtual                 |   workload
    # Swap  |                 | ^
    #  |    |                 | |
    #  |    |                 | |Solaris swap allocation
    #  |    |                 | |begins with Physical
    #  |    +-----------------+ |Swap and grows into
    #  |    |Physical         | |RAM Backed Swap
    #  |    |(Disk Backed)    | |
    #  |    |Swap             | |
    #  |    |(constant)       | |
    #  +--> +-----------------+ +
    #
    #
    # It is often necessary to determine the following info:
    # - Total Virtual Swap  (memory[:swap][:total])
    # - Used Virtual Swap   (memory[:swap][:total] - memory[:swap][:free])
    # - Total Physical Swap (sum of blocks column in 'swap -l' output)
    #   - This is usually what most people want to know
    # - Used Physical Swap  (Total Physical Swap - Used Virtual Swap)
    #   - If Positive, you have Physical (Disk Backed) swap left
    #   - If Negative, All Physical (Disk Backed) Swap has been used/
    #     reserved against, and you're into RAM Backed Swap.
    #     If you expect to have workload related memory shortfalls, you may
    #     need to add more Physical Swap
    tokens = shell_out("swap -s").stdout.strip.split
    used_swap = tokens[8][0..-1].to_i #strip k from end
    free_swap = tokens[10][0..-1].to_i #strip k from end
    # These are really virtual - keep these for the moment for backwards compat
    memory[:swap][:total] = "#{used_swap + free_swap}kB"
    memory[:swap][:free] = "#{free_swap}kB"
    # So name them differently
    memory[:swap][:virtual][:total] = "#{used_swap + free_swap}kB"
    memory[:swap][:virtual][:free] = "#{free_swap}kB"
  end
end
