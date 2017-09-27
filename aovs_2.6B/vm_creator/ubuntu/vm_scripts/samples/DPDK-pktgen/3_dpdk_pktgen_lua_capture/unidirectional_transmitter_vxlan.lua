-- RFC2544 Throughput Test
-- as defined by https://www.ietf.org/rfc/rfc2544.txt

package.path = package.path ..";?.lua;test/?.lua;app/?.lua;../?.lua"

require "Pktgen";

--define packet sizes to test
local pkt_sizes    = { 64, 128, 256, 512, 1024, 1280, 1450 };
--local pkt_sizes = {};
--for i=64,127,4 do ; table.insert(pkt_sizes, i); end
--for i=128,255,8 do ; table.insert(pkt_sizes, i); end
--for i=256,511,16 do ; table.insert(pkt_sizes, i); end
--for i=512,1518,32 do ; table.insert(pkt_sizes, i); end


-- local pkt_sizes   = { 64 };

-- Time in seconds to transmit for
local duration    = 10000;
local confirmDuration = 60000;
local pauseTime   = 5000;

local initialRate = 1 ;

local function setupTraffic()
 
-- Single-packet mode configuration
  for c=0, pktgen.portCount()-1, 1
  do
    pktgen.set_ipaddr(tonumber(c), "dst", "10.10.10." ..  tonumber(c) + 1); 
    pktgen.set_ipaddr(tonumber(c), "src",  "10.10.10." ..  tonumber(c) + 1 + 100 .. "/24"); 
  end

  -- Get MAC address via ARP
  pktgen.set_range("all", "off");
  pktgen.process("all", "on");
  pktgen.mac_from_arp("on");
  pktgen.icmp_echo("all", "on");

  -- Send ARP requests
  for c=0, 10, 1
  do
    pktgen.send_arp("all","r");
    pktgen.delay(10);
  end 

  -- Send ICMP requests
  pktgen.set_proto("all", "icmp");
  for c=0, 10, 1
  do
    pktgen.ping4("all");
    pktgen.delay(10);
  end

  -- Convert single-packet mode output into multi-packet mode output
  pktgen.save("/root/temp.txt");
  pktgen.stop("all");
  for c=0, pktgen.portCount()-1, 1
  do
  
-- Search exported configuration file for single-packet mode entries
    file = io.open("/root/temp.txt", "r");
    str = file:read"*a";
    mac = string.match(str, "set " .. tonumber(c) .. " dst mac (%w+:%w+:%w+:%w+:%w+:%w+)");
    printf("iteration[" .. tonumber(c) .. "] - " .. mac .. "\n");

    -- Set destination MAC
    pktgen.dst_mac(tonumber(c), "start", mac);
    pktgen.dst_mac(tonumber(c), "inc", "00:00:00:00:00:00");
    pktgen.dst_mac(tonumber(c), "min", "00:00:00:00:00:00");
    pktgen.dst_mac(tonumber(c), "max", "00:00:00:00:00:00");

    -- Set destination IP
    pktgen.dst_ip(tonumber(c), "start", "10.10.10." .. tonumber(c) + 1);
    pktgen.dst_ip(tonumber(c), "inc", "0.0.0.0");
    pktgen.dst_ip(tonumber(c), "min", "0.0.0.0");
    pktgen.dst_ip(tonumber(c), "max", "0.0.0.0");

    -- Set source IP
    pktgen.src_ip(tonumber(c), "start", "10.10.10." .. tonumber(c) + 101);
    pktgen.src_ip(tonumber(c), "inc", "0.0.0.0");
    pktgen.src_ip(tonumber(c), "min", "0.0.0.0");
    pktgen.src_ip(tonumber(c), "max", "0.0.0.0");

    -- Set source port
    pktgen.src_port(tonumber(c), "start", 1024*(tonumber(c)+1));
    pktgen.src_port(tonumber(c), "min",   0);
    pktgen.src_port(tonumber(c), "max",   0);
    pktgen.src_port(tonumber(c), "inc",   0);

    -- Set destination port
    pktgen.dst_port(tonumber(c), "start", 1024*(tonumber(c)+1));
    pktgen.dst_port(tonumber(c), "min",   1024*(tonumber(c)+1));
    pktgen.dst_port(tonumber(c), "max",   1024*(tonumber(c)+2));
    pktgen.dst_port(tonumber(c), "inc",   1);

    -- Set packet size
    pktgen.pkt_size("all", "start", 64);
    pktgen.pkt_size("all", "inc", 0);
    pktgen.pkt_size("all", "min", 0);
    pktgen.pkt_size("all", "max", 0);
  end
  -- pktgen.page("range");
  pktgen.set_range("all", "on");
  pktgen.save("/root/temp.txt");
end

function main()
  -- pktgen.screen("off");
  printf("Port Count %d\n", pktgen.portCount());
  printf("Total port Count %d\n", pktgen.totalPorts());


  for _, size in pairs(pkt_sizes)
  do
    pktgen.stop("all");
    setupTraffic()
    pktgen.delay(1000);
    pktgen.set("all", "rate", 100);
    pktgen.pkt_size("all", "start", size);
    pktgen.start("all");
    pktgen.delay(20000);
  end
end

main();
os.exit(0);
