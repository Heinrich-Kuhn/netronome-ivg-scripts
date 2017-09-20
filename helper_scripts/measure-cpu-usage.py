#! /usr/bin/python
# 1. IMPORTS
# -------------------------------------------------1
import re
import sys
import time
import argparse

sys.path.append('../')
import Framework.utilities as ut
# -------------------------------------------------1


class Measure_cpu(object):

    def parse_args(self, argv=None):
        """Read user input parameters using ArgumentParser"""
        fields = ['usr', 'gnice', 'sys', 'iowait',
                  'irq', 'soft', 'steal', 'guest', 'idle']
        __format = argparse.RawTextHelpFormatter
        parser = argparse.ArgumentParser(description='Measure CPU usage',
                                         formatter_class=__format)
        parser.add_argument('-t', '--time',
                            type=int,
                            default=2,
                            help=('Frequency of cpu measurements\n'
                                  'Defaults is 5s'))
        parser.add_argument('-f', '--file',
                            type=str,
                            default="",
                            help='Add prefix to .csv timestamped results file')
        parser.add_argument('-c', '--cpus',
                            type=str,
                            help=('Specify cpus to be measured\n'
                                  ' [EMPTY]    Will measure the combined '
                                  'cpu usage\n'
                                  ' -c ALL     Will measure each cpu and the '
                                  'combined cpu usage\n'
                                  ' -c 1,2,3   Will measure cpu 1,2 and 3'))
        parser.add_argument('-r', '--results',
                            choices=fields,
                            default=fields,
                            metavar='',
                            help=('Choose what fields should be measured\n'
                                  'Available options:\n'
                                  '{}\n'
                                  ).format(fields)
                            )
        return parser.parse_args(argv)

    def __init__(self):
        args = self.parse_args()
        # 1.1 Time
        self.time = args.time

        # 1.2 File
        __date = time.strftime("%Y-%m-%d-%H-%M")
        ut.create_folder('cpu')
        self.file_name = "cpu/{}{}.csv".format(args.file, __date)

        # 1.3 Results
        self.result_parameters = args.results

        # 1.4 Cpus
        if args.cpus is None:
            self.cpus = ""
        else:
            self.cpus = "-P {}".format(args.cpus)

        # 1.5 List of cpus
        if args.cpus is None:
            self.measured_cpus = 'all (combined)'
        elif args.cpus == 'ALL':
            self.measured_cpus = 'all (combined & individually)'
        else:
            self.measured_cpus = args.cpus

    def measure_cpu(self):

        # 2.1 Get base heading values
        __name = 'cpu_usage'
        __cmd_mpstat = 'mpstat {} {} > /tmp/{}.txt'.format(self.cpus,
                                                           self.time, __name)
        __cmd_kill = 'kill -9 $(pgrep mpstat) || true'

        ut.run_command('rm -f /tmp/cpu_usage.txt')
        ut.run_command(__cmd_kill)
        print __cmd_mpstat
        ut.run_command(__cmd_mpstat, cmd_wait=False)
        while True:
            __msg = ('Measuring:\t\t{}\n'
                     "CPU's:\t\t\t{}\n"
                     'Sample time:\t\t{}s\n'
                     'Type exit to stop: '
                     ).format(', '.join(self.result_parameters),
                              self.measured_cpus,
                              self.time
                              )
            if 'exit' in raw_input(__msg):
                break
        ut.run_command(__cmd_kill)

        with open('/tmp/{}.txt'.format(__name), 'r') as f:
            measurement = f.readlines()
        all_headings = re.sub(' +', ' ', measurement[2]).split()

        result = []
        for data in measurement[3:]:

            try:
                headings = all_headings[:]
                data_list = re.sub(' +', ' ', data).split()
                # 2.3 Extract desired fields
                for field in ['usr', 'nice', 'sys', 'iowait', 'irq',
                              'soft', 'steal', 'guest', 'gnice', 'idle']:
                    if field not in self.result_parameters:
                        index = headings.index('%{}'.format(field))
                        del data_list[index]
                        del headings[index]
                del data_list[1]
                headings[0] = 'Time'
                del headings[1]
                result.append(','.join(data_list))
            except Exception:
                print "Failed to parse:\t{}".format(data)

        with open(self.file_name, 'w') as f:
            f.write(','.join(headings))
            f.write('\n')
        with open(self.file_name, 'a') as f:
            f.write('\n'.join(result))
            f.write('\n')
        __cmd_print = 'cat {}'.format(self.file_name)
        print ''.join([l for l in ut.run_command(__cmd_print)])
        print "\nFILE NAME:\t{}\n".format(self.file_name)
        return


if __name__ == "__main__":
    """Run tests"""
    mc = Measure_cpu()
    mc.measure_cpu()
    sys.exit(0)
