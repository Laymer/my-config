import subprocess
import os
import sys

def gen(options):
    lines = [
        "background no",
        "cpu_avg_samples 2",
        "net_avg_samples 2",
        "out_to_console no",
        "use_xft yes",
        "xftfont Input:size=12",
        "xftalpha 0.5",
        # Update interval in seconds
        "update_interval 1"];

    if options["with-awesome"]: 
        lines.extend([
            # Create own window instead of using desktop (required in nautilus)
            "own_window yes",
            # "own_window_transparent yes",
            "own_window_colour 000000",
            "own_window_argb_visual yes",
            "own_window_argb_value 128",
            "own_window_class Conky",
            "own_window_type desktop",
            # "own_window_hints below,skip_taskbar,skip_pager",
            # "minimum_size 800 40",
            # "maximum_width 800"
        ])
        
    lines.extend([
        # Use double buffering (reduces flicker, may not work for everyone)
        "double_buffer yes",
        # Draw shades?
        "draw_shades no",
        # Draw outlines?
        "draw_outline no",
        # Draw borders around text
        "draw_borders no",
        "border_inner_margin 20",
        # Stippled borders?
        "stippled_borders 8",
        # Default colors and also border colors
        "default_color white",
        "default_shade_color black",
        "default_outline_color black",
        "alignment middle_right"
    ])

    lines.extend([
        # Gap between borders of screen and text
        "gap_x 100",
        "gap_y 100",
        # Add spaces to keep things from moving about?  This only affects certain objects.
        "use_spacer left",
        # Subtract file system buffers from used memory?
        "no_buffers yes",
        # set to yes if you want all text to be in uppercase
        "uppercase no",
        "pad_percents 2"
    ])

    lines.append("TEXT")

    cpu_count = int(subprocess.check_output("nproc"))

    # print cpu stats
    sys.stderr.write("Found {0} cpus".format(cpu_count))
    lines.extend([
        "${alignc}==== ${color orange}PERF${color} ====",
        ""
    ])
    first = True
    for cpu in range(0, cpu_count):
        if first:
            lines.append("${{cpu cpu{0}}}%,${{freq_g {0}}}\\".format(cpu + 1)) 
            first = False
        else:
            lines.append("|${{cpu cpu{0}}}%,${{freq_g {0}}}\\".format(cpu + 1))
    lines.append("")

    lines.extend([
        "",
        "${alignc}${color orange}Proc:${color} $running_processes/$processes, ${color orange}Load${color} ${loadavg 3}",
        "${alignc}${color orange}Mem:${color} $memperc%, ${color orange}Swap:${color} $swapperc%"
        ])

    lines.append("")
    lines.append("${alignc}==== ${color orange}NET${color} ====")
    lines.append("")
    for if_name in os.listdir("/sys/class/net"):
        if if_name == "lo":
            continue
        wireless = os.access("/sys/class/net/{0}/wireless".format(if_name), os.R_OK)
        lines.append("${alignc}\\")
        if wireless:
            lines.append("{0}: ${{addr {0}}} - ${{wireless_link_qual_perc {0}}}%".format(if_name))
        else:
            lines.append("{0}: ${{addr {0}}}".format(if_name))
        lines.append("${{alignc}}${{upspeed {0}}}/${{downspeed {0}}}".format(if_name))
        lines.append("")

    lines.extend([
        "",
        "${alignc}==== ${color orange}MISC${color} ====",
        "",
        "${alignc}${color orange}BAT:${color} ${battery}",
        "",
        "${alignc}${time %a %d/%m/%Y} ${time %H:%M}"
        ])

    return lines

def main(args):
    lines = gen({ "with-awesome" : True })
    sys.stdout.write("\n".join(lines))

if __name__ == "__main__":
    main(sys.argv[1:])
