-- RFC2544 Throughput Test
-- as defined by https://www.ietf.org/rfc/rfc2544.txt

package.path = package.path ..";?.lua;test/?.lua;app/?.lua;../?.lua"

require "Pktgen";

-- Time in seconds to transmit for
local pauseTime   = 1000;
local filename_prefix    = "/root/capture";
local filename_suffix    = ".txt";
local globalStartTime    = os.time();
local previous_framesize = -1;
local valid_capture_counter = 0;
local shutdown_counter = 0;
local sample_framesize_buffer = {};

local function writeStatsHeader(filename)
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
--    print("ibytes[" .. tonumber(c) .. "]: " .. portRates[tonumber(c)]["ibytes"]);
--    print("ipackets[" .. tonumber(c) .. "]: " .. portRates[tonumber(c)]["ipackets"]);
--    print("pkts_rx[" .. tonumber(c) .. "]: " .. portRates[tonumber(c)]["pkts_rx"]);
--    print("mbits_rx[" .. tonumber(c) .. "]: " .. portRates[tonumber(c)]["mbits_rx"]);
  end
-- prints("pktStats", pktgen.pktStats("all"));
-- prints("portRates", pktgen.portStats("all", "rate"));
-- prints("portStats", pktgen.portStats("all", "port"));
  local framesize = math.floor(total_ibytes / total_ipackets + 4 + 0.5)
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
  print("-- " .. time_diff .. "," .. pktgen.portCount() .. "," .. math.floor(framesize) .. "," .. total_pkts_rx .. "," .. total_mbits_rx .."\n");

  if (total_pkts_rx > 10000)
  then
    valid_capture_counter = valid_capture_counter + 1;
    shutdown_counter = 0
  else
    valid_capture_counter = 0;
    shutdown_counter = shutdown_counter + 1;
  end

  local average_framesize = 0;
  local count = 0
  for index, value in pairs(sample_framesize_buffer)
  do
    average_framesize = average_framesize + value
    count = count + 1
  end
  average_framesize = math.floor(average_framesize/count + 0.5);

  if average_framesize ~= previous_framesize 
  then
    valid_capture_counter = 0;
    previous_framesize = average_framesize
  end

  if (valid_capture_counter >= 0) 
  then
    writeSample(filename, time_diff, pktgen.portCount(), average_framesize, total_pkts_rx, total_mbits_rx);
  end

  if (shutdown_counter > 60)
  then
    os.exit(0);
  end
end

local function setupTraffic()
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
      pktgen.delay(pauseTime);
  end
end

main();
os.exit(0);

