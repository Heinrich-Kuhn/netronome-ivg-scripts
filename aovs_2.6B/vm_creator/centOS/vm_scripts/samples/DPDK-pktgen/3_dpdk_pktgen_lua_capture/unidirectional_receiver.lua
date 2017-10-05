-- RFC2544 Throughput Test
-- as defined by https://www.ietf.org/rfc/rfc2544.txt

package.path = package.path ..";?.lua;test/?.lua;app/?.lua;../?.lua"

require "Pktgen";

-- Time in seconds to transmit for
local sampleTime   = 1000;
local filename_prefix    = "/root/capture";
local filename_suffix    = ".txt";
local globalStartTime    = os.time();
local previous_framesize = -1;
local previous_framerate = -1;
local valid_capture_counter = 0;
local shutdown_counter = 0;
local sample_framesize_buffer = {};

local function writeStatsHeader(filename)
-- Overwrite results file
  file = io.open(filename, "w")
  local headerString = string.format(
    "%10s,%10s,%10s,%15s,%15s\n",
    "Time",
    "Ports",
    "Framesize",
    "total_pkts_rx",
    "total_mbits_rx"
  )
  file:write(headerString)
  file:close()
end

local function writeSample(filename, time_diff, ports, framesize, total_pkts_rx, total_mbits_rx)
-- Append to results file
  file = io.open(filename, "a")
  local statsString = string.format(
    "%10s,%10s,%10s,%15s,%15s\n",
    time_diff,
    ports,
    framesize,
    total_pkts_rx,
    total_mbits_rx
  )
  file:write(statsString)
  file:close()
end

local function captureSample(filename)
  local now = os.time()
  local time_diff = os.difftime(now, globalStartTime)
  stats = pktgen.portStats("all", "port");
  portRates = pktgen.portStats("all", "rate");

  total_ibytes = 0
  total_ipackets = 0
  total_pkts_rx = 0
  total_mbits_rx = 0
  for c=0, pktgen.portCount()-1, 1
  do
    total_ibytes = total_ibytes + portRates[tonumber(c)]["ibytes"];
    total_ipackets = total_ipackets + portRates[tonumber(c)]["ipackets"];
    total_pkts_rx = total_pkts_rx + portRates[tonumber(c)]["pkts_rx"];
    total_mbits_rx = total_mbits_rx + portRates[tonumber(c)]["mbits_rx"];
  end

-- No "round" function in LUA
-- 4 byte/32 bits offset FCS (Framecheck sequence) not included in measurements
  local framesize = math.floor(total_ibytes / total_ipackets + 4 + 0.5)

-- Store 5 samples in buffer used to determine framesize received
-- Reduce false positves where the estimated framesize differs by 1 by based on portStats counters snapshot
  table.insert(sample_framesize_buffer, framesize) 
  local count = 0
  for index, value in pairs(sample_framesize_buffer) 
  do
    count = count + 1
  end
  if (count > 5)
  then
    table.remove(sample_framesize_buffer, 1);
  end
  print("-- " .. time_diff .. "," .. pktgen.portCount() .. "," .. framesize .. "," .. total_pkts_rx .. "," .. total_mbits_rx .."\n");

-- Minimum framerate to determine active TX state
  if (total_pkts_rx > 10000)
  then
    valid_capture_counter = valid_capture_counter + 1;
    shutdown_counter = 0
  else
    valid_capture_counter = 0;
    shutdown_counter = shutdown_counter + 1;
  end

-- Ensure framerate has stabilised (reduce trailing start/stop samples)
  if (math.abs((previous_framerate-total_pkts_rx)/previous_framerate) > 0.05)
  then
    valid_capture_counter = 0;
  end 
  previous_framerate = total_pkts_rx

-- Calculate average framesize of sample buffer
  local average_framesize = 0;
  local count = 0
  for index, value in pairs(sample_framesize_buffer)
  do
    average_framesize = average_framesize + value
    count = count + 1
  end
  average_framesize = math.floor(average_framesize/count + 0.5);

-- If the framesize changes, reset the counter which tracks valid samples
  if average_framesize ~= previous_framesize 
  then
    valid_capture_counter = 0;
    previous_framesize = average_framesize
  end

-- Need two or more consecutive valid samples before writing sample to file
  if (valid_capture_counter >= 2) 
  then
    writeSample(filename, time_diff, pktgen.portCount(), average_framesize, total_pkts_rx, total_mbits_rx);
  end

-- Shutdown automatically after 60 seconds of inactivty
  if (shutdown_counter > 60)
  then
    os.exit(0);
  end
end

local function setupTraffic()
-- IP addreses on RX side are 10.10.10.[1,2,3,4..]/24
  for c=0, pktgen.portCount()-1, 1
  do
    pktgen.set_ipaddr(tonumber(c), "dst", "10.10.10." ..  tonumber(c) + 1 + 100);
    pktgen.set_ipaddr(tonumber(c), "src",  "10.10.10." ..  tonumber(c) + 1 .. "/24");
  end
  pktgen.process("all", "on");
  pktgen.mac_from_arp("on");
  pktgen.icmp_echo("all", "on");
end

function main()
  pktgen.screen("off");
  setupTraffic();
  printf("Port Count %d\n", pktgen.portCount());
  printf("Total port Count %d\n", pktgen.totalPorts());
  local now = os.time()
  local filename = filename_prefix .. filename_suffix
  writeStatsHeader(filename)
  while 1
  do
      captureSample(filename);
      pktgen.delay(sampleTime);
  end
end

main();
os.exit(0);

