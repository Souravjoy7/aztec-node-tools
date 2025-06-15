#!/bin/bash

# Version 3.2 - Fixed consensus validation logic
# Original by SOUROV JOY - Enhanced with proper consensus failure handling

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}🏥 NODE-STANDARD RPC HEALTH CHECK SYSTEM${NC}"
echo -e "${BLUE}By SOUROV JOY - Enhanced Performance Standards${NC}"
echo -e "${BLUE}===============================================${NC}"

# Input collection
read -p "L1 RPC URL: " RPC_URL
read -p "Consensus URL: " CONS_URL

# Validate inputs
if [[ -z "$RPC_URL" || -z "$CONS_URL" ]]; then
    echo -e "${RED}❌ Error: Both RPC URL and Consensus URL are required${NC}"
    exit 1
fi

# Initialize arrays for multiple measurements
declare -a rpc_times=()
declare -a cons_rpc_times=()
declare -a block_times=()
declare -a l1_status_codes=()
declare -a cons_status_codes=()
declare -a l1_json_errors=()
declare -a cons_json_errors=()

# Global variables
l1_rate_limit_status="UNKNOWN"
l1_rate_limit_details=""
cons_rate_limit_status="UNKNOWN"
cons_rate_limit_details=""
consensus_functional=false
beacon_finality_working=false
beacon_head_working=false

echo -e "\n${GREEN}🔍 Starting comprehensive RPC health check with Node standards...${NC}"

# Function to calculate average from array
calculate_average() {
    local arr=("$@")
    local sum=0
    local count=${#arr[@]}
    
    if [ $count -eq 0 ]; then
        echo "0"
        return
    fi
    
    for value in "${arr[@]}"; do
        if command -v bc >/dev/null 2>&1; then
            sum=$(echo "$sum + $value" | bc -l 2>/dev/null || echo "$sum + $value" | awk '{print $1 + $3}')
        else
            sum=$(awk -v s="$sum" -v v="$value" 'BEGIN {print s + v}')
        fi
    done
    
    if command -v bc >/dev/null 2>&1; then
        echo "scale=4; $sum / $count" | bc -l
    else
        awk -v s="$sum" -v c="$count" 'BEGIN {printf "%.4f", s/c}'
    fi
}

# Industry-standard latency classification
classify_latency() {
    local latency=$1
    local latency_ms
    
    if command -v bc >/dev/null 2>&1; then
        latency_ms=$(echo "scale=2; $latency * 1000" | bc -l)
        if (( $(echo "$latency == 0" | bc -l) )); then
            echo "Invalid"
        elif (( $(echo "$latency_ms < 25" | bc -l) )); then
            echo "Excellent"
        elif (( $(echo "$latency_ms < 50" | bc -l) )); then
            echo "Good"
        elif (( $(echo "$latency_ms < 200" | bc -l) )); then
            echo "Acceptable"
        elif (( $(echo "$latency_ms < 500" | bc -l) )); then
            echo "Slow"
        else
            echo "Very Slow"
        fi
    else
        if awk -v l="$latency" 'BEGIN {exit (l == 0)}'; then
            echo "Invalid"
        elif awk -v l="$latency" 'BEGIN {exit (l >= 0.025)}'; then
            echo "Excellent"
        elif awk -v l="$latency" 'BEGIN {exit (l >= 0.05)}'; then
            echo "Good"
        elif awk -v l="$latency" 'BEGIN {exit (l >= 0.2)}'; then
            echo "Acceptable"
        elif awk -v l="$latency" 'BEGIN {exit (l >= 0.5)}'; then
            echo "Slow"
        else
            echo "Very Slow"
        fi
    fi
}

# Enhanced consensus functionality validation
validate_consensus_functionality() {
    local url=$1
    echo -e "${PURPLE}🔍 Validating Consensus Functionality...${NC}"
    
    # Test beacon finality
    beacon_finalized_response=$(curl -s "$url/eth/v1/beacon/headers/finalized" 2>/dev/null)
    if command -v jq >/dev/null 2>&1; then
        beacon_finalized=$(echo "$beacon_finalized_response" | jq -r '.data.header.message.slot' 2>/dev/null)
    else
        beacon_finalized=$(echo "$beacon_finalized_response" | grep -o '"slot":"[^"]*"' | head -1 | cut -d'"' -f4)
    fi
    
    if [[ "$beacon_finalized" != "null" && -n "$beacon_finalized" && "$beacon_finalized" != "" ]]; then
        echo -e "${GREEN}   ✅ Beacon Finality: Working (Slot: $beacon_finalized)${NC}"
        beacon_finality_working=true
    else
        echo -e "${RED}   ❌ Beacon Finality: Failed${NC}"
        beacon_finality_working=false
    fi
    
    # Test beacon head
    beacon_head_response=$(curl -s "$url/eth/v1/beacon/headers/head" 2>/dev/null)
    if command -v jq >/dev/null 2>&1; then
        beacon_head=$(echo "$beacon_head_response" | jq -r '.data.header.message.slot' 2>/dev/null)
    else
        beacon_head=$(echo "$beacon_head_response" | grep -o '"slot":"[^"]*"' | head -1 | cut -d'"' -f4)
    fi
    
    if [[ "$beacon_head" != "null" && -n "$beacon_head" && "$beacon_head" != "" ]]; then
        echo -e "${GREEN}   ✅ Beacon Head: Working (Slot: $beacon_head)${NC}"
        beacon_head_working=true
    else
        echo -e "${RED}   ❌ Beacon Head: Failed${NC}"
        beacon_head_working=false
    fi
    
    # Test sync status
    syncing_response=$(curl -s "$url/eth/v1/node/syncing" 2>/dev/null)
    if command -v jq >/dev/null 2>&1; then
        syncing=$(echo "$syncing_response" | jq -r '.data.is_syncing' 2>/dev/null)
    else
        syncing=$(echo "$syncing_response" | grep -o '"is_syncing":[^,}]*' | cut -d':' -f2 | tr -d ' "')
    fi
    
    # Test node identity
    identity_response=$(curl -s "$url/eth/v1/node/identity" 2>/dev/null)
    if command -v jq >/dev/null 2>&1; then
        client_id=$(echo "$identity_response" | jq -r '.data.client_name' 2>/dev/null)
        peers=$(echo "$identity_response" | jq -r '.data.peer_count' 2>/dev/null)
    else
        client_id="unknown"
        peers="0"
    fi
    
    # Determine overall consensus functionality
    if [[ "$beacon_finality_working" == true && "$beacon_head_working" == true ]]; then
        consensus_functional=true
        echo -e "${GREEN}   ✅ Consensus Overall: Functional${NC}"
    else
        consensus_functional=false
        echo -e "${RED}   ❌ Consensus Overall: Failed${NC}"
    fi
}

# Enhanced rate limiting detection for L1 RPC
detect_l1_rate_limit() {
    local url=$1
    local limit_detected=false
    local consecutive_requests=10
    local request_times=()
    local status_codes=()
    local json_errors=()
    
    echo -e "${YELLOW}🚦 Testing L1 RPC rate limiting (${consecutive_requests} requests)...${NC}"
    
    for ((i=1; i<=consecutive_requests; i++)); do
        printf " L1 Request %d/%d...\r" $i $consecutive_requests
        
        response=$(curl -s -w "HTTPCODE:%{http_code}\nTIME:%{time_total}" \
                   -X POST -H "Content-Type: application/json" \
                   --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
                   "$url" 2>/dev/null)
        
        http_code=$(echo "$response" | grep "HTTPCODE:" | cut -d: -f2)
        response_time=$(echo "$response" | grep "TIME:" | cut -d: -f2)
        json_response=$(echo "$response" | sed '/HTTPCODE:/,$d')
        
        request_times+=($response_time)
        status_codes+=($http_code)
        
        if [[ "$http_code" == "429" ]] || [[ "$http_code" == "503" ]] || [[ "$http_code" == "402" ]] || [[ "$http_code" == "403" ]]; then
            limit_detected=true
        fi
        
        if command -v jq >/dev/null 2>&1 && echo "$json_response" | jq -e '.error.code' >/dev/null 2>&1; then
            error_code=$(echo "$json_response" | jq -r '.error.code')
            if [[ "$error_code" == "-32029" ]] || [[ "$error_code" == "-33000" ]] || [[ "$error_code" == "-33200" ]] || [[ "$error_code" == "-32005" ]]; then
                limit_detected=true
                json_errors+=("$error_code")
            fi
        fi
        
        sleep 0.1
    done
    
    echo
    
    local avg_time=$(calculate_average "${request_times[@]}")
    local failed_requests=0
    for code in "${status_codes[@]}"; do
        if [[ "$code" != "200" ]]; then
            ((failed_requests++))
        fi
    done
    
    local failure_rate=0
    if [[ $consecutive_requests -gt 0 ]]; then
        if command -v bc >/dev/null 2>&1; then
            failure_rate=$(echo "scale=2; $failed_requests * 100 / $consecutive_requests" | bc -l)
        else
            failure_rate=$(awk -v f="$failed_requests" -v c="$consecutive_requests" 'BEGIN {printf "%.2f", f*100/c}')
        fi
    fi
    
    if [ "$limit_detected" = true ]; then
        l1_rate_limit_status="DETECTED"
        l1_rate_limit_details="HTTP codes: ${status_codes[*]}, JSON errors: ${json_errors[*]}"
    elif command -v bc >/dev/null 2>&1 && (( $(echo "$failure_rate > 20" | bc -l) )); then
        l1_rate_limit_status="LIKELY"
        l1_rate_limit_details="High failure rate: ${failure_rate}%"
    elif command -v bc >/dev/null 2>&1 && (( $(echo "$avg_time > 3.0" | bc -l) )); then
        l1_rate_limit_status="POSSIBLE"
        l1_rate_limit_details="Slow average response time"
    else
        l1_rate_limit_status="NONE"
        l1_rate_limit_details="All tests passed"
    fi
    
    echo -e "${BLUE}📈 L1 Statistics: Avg time: ${avg_time}s, Failure rate: ${failure_rate}%${NC}"
}

# Enhanced rate limiting detection for Consensus RPC
detect_consensus_rate_limit() {
    local url=$1
    local limit_detected=false
    local consecutive_requests=10
    local request_times=()
    local status_codes=()
    
    echo -e "${PURPLE}🚦 Testing Consensus RPC rate limiting (${consecutive_requests} requests)...${NC}"
    
    local endpoints=(
        "/eth/v1/node/health"
        "/eth/v1/beacon/headers/head"
        "/eth/v1/node/syncing"
        "/eth/v1/node/identity"
        "/eth/v1/beacon/headers/finalized"
    )
    
    for ((i=1; i<=consecutive_requests; i++)); do
        printf " Consensus Request %d/%d...\r" $i $consecutive_requests
        
        local endpoint_index=$((i % ${#endpoints[@]}))
        local test_endpoint="${endpoints[$endpoint_index]}"
        
        response=$(curl -s -w "HTTPCODE:%{http_code}\nTIME:%{time_total}" \
                   -H "Accept: application/json" \
                   "$url$test_endpoint" 2>/dev/null)
        
        http_code=$(echo "$response" | grep "HTTPCODE:" | cut -d: -f2)
        response_time=$(echo "$response" | grep "TIME:" | cut -d: -f2)
        
        request_times+=($response_time)
        status_codes+=($http_code)
        
        if [[ "$http_code" == "429" ]] || [[ "$http_code" == "503" ]] || [[ "$http_code" == "402" ]] || [[ "$http_code" == "403" ]]; then
            limit_detected=true
        fi
        
        sleep 0.1
    done
    
    echo
    
    local avg_time=$(calculate_average "${request_times[@]}")
    local failed_requests=0
    for code in "${status_codes[@]}"; do
        if [[ "$code" != "200" ]]; then
            ((failed_requests++))
        fi
    done
    
    local failure_rate=0
    if [[ $consecutive_requests -gt 0 ]]; then
        if command -v bc >/dev/null 2>&1; then
            failure_rate=$(echo "scale=2; $failed_requests * 100 / $consecutive_requests" | bc -l)
        else
            failure_rate=$(awk -v f="$failed_requests" -v c="$consecutive_requests" 'BEGIN {printf "%.2f", f*100/c}')
        fi
    fi
    
    if [ "$limit_detected" = true ]; then
        cons_rate_limit_status="DETECTED"
        cons_rate_limit_details="HTTP codes: ${status_codes[*]}"
    elif command -v bc >/dev/null 2>&1 && (( $(echo "$failure_rate > 20" | bc -l) )); then
        cons_rate_limit_status="LIKELY"
        cons_rate_limit_details="High failure rate: ${failure_rate}%"
    elif command -v bc >/dev/null 2>&1 && (( $(echo "$avg_time > 3.0" | bc -l) )); then
        cons_rate_limit_status="POSSIBLE"
        cons_rate_limit_details="Slow average response time"
    else
        cons_rate_limit_status="NONE"
        cons_rate_limit_details="All tests passed"
    fi
    
    echo -e "${PURPLE}📈 Consensus Statistics: Avg time: ${avg_time}s, Failure rate: ${failure_rate}%${NC}"
}

# Block production rate classification
classify_block_time() {
    local block_time=$1
    local expected_time=12.0
    
    if command -v bc >/dev/null 2>&1; then
        if (( $(echo "$block_time == 0" | bc -l) )); then
            echo "Invalid"
        elif (( $(echo "$block_time < $expected_time * 0.8" | bc -l) )); then
            echo "Excellent"
        elif (( $(echo "$block_time <= $expected_time * 1.2" | bc -l) )); then
            echo "Good"
        elif (( $(echo "$block_time <= $expected_time * 1.5" | bc -l) )); then
            echo "Slow"
        else
            echo "Very Slow"
        fi
    else
        if awk -v bt="$block_time" 'BEGIN {exit (bt != 0)}'; then
            echo "Invalid"
        elif awk -v bt="$block_time" -v et="$expected_time" 'BEGIN {exit (bt >= et * 0.8)}'; then
            echo "Excellent"
        elif awk -v bt="$block_time" -v et="$expected_time" 'BEGIN {exit (bt > et * 1.2)}'; then
            echo "Good"
        elif awk -v bt="$block_time" -v et="$expected_time" 'BEGIN {exit (bt > et * 1.5)}'; then
            echo "Slow"
        else
            echo "Very Slow"
        fi
    fi
}

# Enhanced verdict calculation with proper consensus failure handling
calculate_verdict() {
    local score=0
    
    # CRITICAL CHECK 1: 20-second block production validation
    if [[ $age -gt 20 ]]; then
        echo -e "${RED}CRITICAL: Block production time exceeded 20 seconds - Node automatically fails${NC}"
        echo 0
        return
    fi
    
    # CRITICAL CHECK 2: Consensus functionality validation
    if [[ "$consensus_functional" == false ]]; then
        echo -e "${RED}CRITICAL: Consensus RPC failed - No beacon finality or head - Node automatically fails${NC}"
        echo 0
        return
    fi
    
    # CRITICAL CHECK 3: Complete L1 RPC failure
    if [[ "$l1_rate_limit_status" == "DETECTED" && "$avg_l1_time" == "0" ]]; then
        echo -e "${RED}CRITICAL: L1 RPC completely failed - Node automatically fails${NC}"
        echo 0
        return
    fi
    
    # CRITICAL CHECK 4: Complete Consensus RPC failure
    if [[ "$cons_rate_limit_status" == "DETECTED" && "$avg_cons_time" == "0" ]]; then
        echo -e "${RED}CRITICAL: Consensus RPC completely failed - Node automatically fails${NC}"
        echo 0
        return
    fi
    
    # L1 RPC Response Time (35 points)
    if command -v bc >/dev/null 2>&1; then
        local latency_ms=$(echo "scale=2; $avg_rpc_time * 1000" | bc -l)
        if (( $(echo "$latency_ms < 25" | bc -l) )); then
            score=$((score + 35))
        elif (( $(echo "$latency_ms < 50" | bc -l) )); then
            score=$((score + 30))
        elif (( $(echo "$latency_ms < 200" | bc -l) )); then
            score=$((score + 20))
        elif (( $(echo "$latency_ms < 500" | bc -l) )); then
            score=$((score + 10))
        else
            score=$((score + 5))
        fi
    else
        if awk -v t="$avg_rpc_time" 'BEGIN {exit (t >= 0.025)}'; then
            score=$((score + 35))
        elif awk -v t="$avg_rpc_time" 'BEGIN {exit (t >= 0.05)}'; then
            score=$((score + 30))
        else
            score=$((score + 20))
        fi
    fi
    
    # Consensus RPC Response Time (20 points)
    if command -v bc >/dev/null 2>&1; then
        local cons_latency_ms=$(echo "scale=2; $avg_cons_time * 1000" | bc -l)
        if (( $(echo "$cons_latency_ms < 25" | bc -l) )); then
            score=$((score + 20))
        elif (( $(echo "$cons_latency_ms < 50" | bc -l) )); then
            score=$((score + 15))
        elif (( $(echo "$cons_latency_ms < 200" | bc -l) )); then
            score=$((score + 10))
        else
            score=$((score + 5))
        fi
    else
        score=$((score + 15))
    fi
    
    # Block Production Rate (20 points)
    if command -v bc >/dev/null 2>&1 && (( $(echo "$avg_block_time > 0" | bc -l) )); then
        if (( $(echo "$avg_block_time < 12.0 * 0.8" | bc -l) )); then
            score=$((score + 20))
        elif (( $(echo "$avg_block_time <= 12.0 * 1.2" | bc -l) )); then
            score=$((score + 15))
        elif (( $(echo "$avg_block_time <= 12.0 * 1.5" | bc -l) )); then
            score=$((score + 10))
        else
            score=$((score + 5))
        fi
    elif [[ "$avg_block_time" != "0" && -n "$avg_block_time" ]]; then
        score=$((score + 15))
    fi
    
    # L1 Rate Limiting (12.5 points)
    case $l1_rate_limit_status in
        "NONE") score=$((score + 12)) ;;
        "POSSIBLE") score=$((score + 8)) ;;
        "LIKELY") score=$((score + 4)) ;;
        "DETECTED") score=$((score + 0)) ;;
    esac
    
    # Consensus Rate Limiting (7.5 points)
    case $cons_rate_limit_status in
        "NONE") score=$((score + 7)) ;;
        "POSSIBLE") score=$((score + 5)) ;;
        "LIKELY") score=$((score + 2)) ;;
        "DETECTED") score=$((score + 0)) ;;
    esac
    
    # Block freshness (5 points) - Only if L1 is functional AND consensus is working
    if [[ $age -gt 30 ]]; then
        echo -e "${RED}Severe: L1 block age $age sec is STALE. Not producing fresh blocks.${NC}"
        score=$((score - 30))
        [[ $score -lt 0 ]] && score=0
    fi
    
    if [[ $age -le 15 ]]; then
        score=$((score + 5))
    elif [[ $age -le 30 ]]; then
        score=$((score + 3))
    else
        score=$((score + 1))
    fi
    
    echo $score
}

# Get basic chain information
echo -e "${BLUE}📋 Collecting basic chain information...${NC}"
chain_id=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' "$RPC_URL" | jq -r .result 2>/dev/null || echo "unknown")
client=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}' "$RPC_URL" | jq -r .result 2>/dev/null || echo "unknown")

# Validate consensus functionality first
validate_consensus_functionality "$CONS_URL"

# Detect rate limiting for both L1 and Consensus
detect_l1_rate_limit "$RPC_URL"
echo
detect_consensus_rate_limit "$CONS_URL"

# Perform 5 measurements for averaging
echo -e "\n${GREEN}📊 Collecting 5 measurements for accurate assessment...${NC}"

for ((i=1; i<=5; i++)); do
    echo -e " ${BLUE}📈 Measurement $i/5...${NC}"
    
    rpc_time=$(curl -s -o /dev/null -w "%{time_total}" -X POST -H "Content-Type: application/json" \
               --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' "$RPC_URL" 2>/dev/null || echo "0")
    rpc_times+=($rpc_time)
    
    cons_time=$(curl -s -o /dev/null -w "%{time_total}" "$CONS_URL/eth/v1/node/health" 2>/dev/null || echo "0")
    cons_rpc_times+=($cons_time)
    
    current_block=$(curl -s -X POST -H "Content-Type: application/json" \
                    --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}' "$RPC_URL" 2>/dev/null)
    
    if command -v jq >/dev/null 2>&1; then
        current_block_hex=$(echo "$current_block" | jq -r .result.number 2>/dev/null)
        current_timestamp_hex=$(echo "$current_block" | jq -r .result.timestamp 2>/dev/null)
    else
        current_block_hex=$(echo "$current_block" | grep -o '"number":"[^"]*"' | cut -d'"' -f4)
        current_timestamp_hex=$(echo "$current_block" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
    fi
    
    if [[ $current_block_hex != "null" && -n $current_block_hex && $current_block_hex != "" && $current_block_hex =~ ^0x[0-9a-fA-F]+$ ]]; then
        current_block_dec=$((16#${current_block_hex:2}))
        current_ts_dec=$((16#${current_timestamp_hex:2}))
        
        prev_block_num=$((current_block_dec - 10))
        prev_block_hex=$(printf '0x%x' $prev_block_num)
        
        prev_block=$(curl -s -X POST -H "Content-Type: application/json" \
                     --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$prev_block_hex\", false],\"id\":1}" "$RPC_URL" 2>/dev/null)
        
        if command -v jq >/dev/null 2>&1; then
            prev_timestamp_hex=$(echo "$prev_block" | jq -r .result.timestamp 2>/dev/null)
        else
            prev_timestamp_hex=$(echo "$prev_block" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
        fi
        
        if [[ $prev_timestamp_hex != "null" && -n $prev_timestamp_hex && $prev_timestamp_hex != "" && $prev_timestamp_hex =~ ^0x[0-9a-fA-F]+$ ]]; then
            prev_ts_dec=$((16#${prev_timestamp_hex:2}))
            time_diff=$((current_ts_dec - prev_ts_dec))
            
            if [[ $time_diff -gt 0 ]]; then
                if command -v bc >/dev/null 2>&1; then
                    block_production_rate=$(echo "scale=4; $time_diff / 10" | bc -l)
                else
                    block_production_rate=$(awk -v td="$time_diff" 'BEGIN {printf "%.4f", td/10}')
                fi
                block_times+=($block_production_rate)
            fi
        fi
    fi
    
    sleep 2
done

# Calculate averages
avg_rpc_time=$(calculate_average "${rpc_times[@]}")
avg_cons_time=$(calculate_average "${cons_rpc_times[@]}")
avg_block_time=$(calculate_average "${block_times[@]}")

# Get additional metrics
echo -e "${BLUE}📊 Collecting additional metrics...${NC}"
latest_block=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}' "$RPC_URL" 2>/dev/null)

if command -v jq >/dev/null 2>&1; then
    block_hex=$(echo "$latest_block" | jq -r .result.number 2>/dev/null)
    timestamp_hex=$(echo "$latest_block" | jq -r .result.timestamp 2>/dev/null)
else
    block_hex=$(echo "$latest_block" | grep -o '"number":"[^"]*"' | cut -d'"' -f4)
    timestamp_hex=$(echo "$latest_block" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
fi

# Safe block processing
if [[ $block_hex == "null" || -z $block_hex || $block_hex == "" || ! $block_hex =~ ^0x[0-9a-fA-F]+$ ]]; then
    echo -e "${RED}❌ Warning: L1 RPC is not producing blocks. Proceeding with other checks...${NC}"
    block_dec="unknown"
    age=999999
else
    block_dec=$((16#${block_hex:2}))
    ts_dec=$((16#${timestamp_hex:2}))
    now=$(date +%s)
    age=$((now - ts_dec))
fi

# Determine block status considering both L1 and consensus
if [[ "$consensus_functional" == false ]]; then
    block_status="CONSENSUS_FAILED"
elif [[ $age -gt 30 ]]; then
    block_status="STALE"
else
    block_status="FRESH"
fi

# Get finalized block
finalized_block=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["finalized", false],"id":1}' "$RPC_URL" 2>/dev/null)

if command -v jq >/dev/null 2>&1; then
    finalized_block_hex=$(echo "$finalized_block" | jq -r .result.number 2>/dev/null)
else
    finalized_block_hex=$(echo "$finalized_block" | grep -o '"number":"[^"]*"' | cut -d'"' -f4)
fi

# Calculate final verdict with enhanced consensus validation
final_score=$(calculate_verdict)

# Display results
echo -e "\n"
echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}🏥 NODE-STANDARD RPC HEALTH CHECK RESULTS SCRIPT BY SOUROV JOY${NC}"
echo -e "${BLUE}======================================================================${NC}"

echo -e "\n${GREEN}📊 BASIC METRICS:${NC}"
if [[ "$chain_id" != "null" && -n "$chain_id" && "$chain_id" != "unknown" ]]; then
    echo "🌐 Chain ID: $((16#${chain_id:2}))"
else
    echo "🌐 Chain ID: Unable to determine"
fi

echo "🔍 Client: $client"

if [[ "$block_dec" != "unknown" ]]; then
    echo "📦 Latest Block: $block_dec | ⏱ Age: ${age}s => $block_status"
else
    echo "📦 Latest Block: | ⏱ Age: ${age}s => $block_status"
fi

if [[ "$finalized_block_hex" != "null" && -n "$finalized_block_hex" && "$finalized_block_hex" != "" ]]; then
    echo "✅ Finalized Block: $((16#${finalized_block_hex:2}))"
else
    echo "❌ Finality not supported"
fi

echo -e "\n${GREEN}⚡ PERFORMANCE METRICS (Node Standards - 5-sample average):${NC}"
if [[ "$consensus_functional" == false ]]; then
    printf "🚀 L1 RPC Response Time: %.4f sec (%.1fms) => %s (CONSENSUS FAILED)\n" $avg_rpc_time $(echo "scale=1; $avg_rpc_time * 1000" | bc -l 2>/dev/null || echo "N/A") "$(classify_latency $avg_rpc_time)"
elif [[ $age -gt 30 ]]; then
    printf "🚀 L1 RPC Response Time: %.4f sec (%.1fms) => Stale Block Detected (age ${age}s)\n" $avg_rpc_time $(echo "scale=1; $avg_rpc_time * 1000" | bc -l 2>/dev/null || echo "N/A")
else
    printf "🚀 L1 RPC Response Time: %.4f sec (%.1fms) => %s\n" $avg_rpc_time $(echo "scale=1; $avg_rpc_time * 1000" | bc -l 2>/dev/null || echo "N/A") "$(classify_latency $avg_rpc_time)"
fi

if [[ "$consensus_functional" == false ]]; then
    printf "🏗️ Consensus RPC Time: %.4f sec (%.1fms) => FAILED (No Beacon Data)\n" $avg_cons_time $(echo "scale=1; $avg_cons_time * 1000" | bc -l 2>/dev/null || echo "N/A")
else
    printf "🏗️ Consensus RPC Time: %.4f sec (%.1fms) => %s\n" $avg_cons_time $(echo "scale=1; $avg_cons_time * 1000" | bc -l 2>/dev/null || echo "N/A") "$(classify_latency $avg_cons_time)"
fi

if [[ "$avg_block_time" != "0" && -n "$avg_block_time" ]]; then
    printf "⛏️ Block Production Rate: %.2f sec/block => %s\n" $avg_block_time "$(classify_block_time $avg_block_time)"
else
    echo "⛏️ Block Production Rate: Unable to calculate"
fi

echo -e "\n${GREEN}🚦 RATE LIMITING STATUS:${NC}"
echo "🔗 L1 RPC: $l1_rate_limit_status"
echo "   Details: $l1_rate_limit_details"
echo "🏗️ Consensus RPC: $cons_rate_limit_status"
echo "   Details: $cons_rate_limit_details"

echo -e "\n${GREEN}🔗 CONSENSUS METRICS:${NC}"
if [[ "$beacon_finality_working" == true ]]; then
    echo "🏁 Beacon Finalized Slot: $beacon_finalized"
else
    echo "❌ No Beacon Finality"
fi

if [[ "$beacon_head_working" == true ]]; then
    echo "📈 Beacon Head Slot: $beacon_head"
else
    echo "❌ No Beacon Head"
fi

if [[ "$syncing" == "false" ]]; then
    echo "✅ Consensus Node is Synced"
elif [[ "$syncing" == "true" ]]; then
    echo "🔄 Consensus Node Syncing: Yes"
else
    echo "🔄 Consensus Node Syncing: $syncing"
fi

echo "🧩 Consensus Client: $client_id | Peers: $peers"

# Final Verdict with enhanced consensus failure detection
echo -e "\n"
echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}🏆 FINAL VERDICT (Node Standards)${NC}"
echo -e "${BLUE}===============================================${NC}"

echo "📊 Overall Score: $final_score/100"

# Enhanced verdict logic with proper consensus failure handling
if [[ $age -gt 20 ]]; then
    echo -e "${RED}❌ VERDICT: NOT SUITABLE FOR NODE${NC}"
    echo -e "${RED}   🚨 CRITICAL FAILURE: Block production time exceeded 20 seconds${NC}"
elif [[ "$consensus_functional" == false ]]; then
    echo -e "${RED}❌ VERDICT: NOT SUITABLE FOR NODE${NC}"
    echo -e "${RED}   🚨 CRITICAL FAILURE: Consensus layer completely failed${NC}"
    echo -e "${RED}   ⚠️  No beacon finality or head data available${NC}"
elif [[ $final_score -ge 90 ]]; then
    echo -e "${GREEN}🥇 VERDICT: BEST FOR NODE${NC}"
    echo -e "${GREEN}   ⭐ Premium-grade performance meeting node excellence standards${NC}"
elif [[ $final_score -ge 75 ]]; then
    echo -e "${YELLOW}🥈 VERDICT: GOOD FOR NODE${NC}"
    echo -e "${YELLOW}   ✅ Production-ready performance with industry-standard metrics${NC}"
elif [[ $final_score -ge 60 ]]; then
    echo -e "${YELLOW}🥉 VERDICT: ACCEPTABLE FOR NODE${NC}"
    echo -e "${YELLOW}   ⚡ Meets basic requirements but has room for improvement${NC}"
else
    echo -e "${RED}❌ VERDICT: NOT SUITABLE FOR NODE${NC}"
    echo -e "${RED}   🚨 Performance issues requiring immediate attention${NC}"
fi

echo -e "\n${BLUE}📝 DETAILED BREAKDOWN:${NC}"
if [[ "$consensus_functional" == false ]]; then
    echo "   • L1 RPC Performance: $(classify_latency $avg_rpc_time) (CONSENSUS FAILED)"
    echo "   • Consensus RPC Performance: FAILED - No Beacon Data"
else
    if [[ $age -gt 30 ]]; then
        echo "   • L1 RPC Performance: Stale Block - Not Producing"
    else
        echo "   • L1 RPC Performance: $(classify_latency $avg_rpc_time)"
    fi
    echo "   • Consensus RPC Performance: $(classify_latency $avg_cons_time)"
fi

if [[ "$avg_block_time" != "0" && -n "$avg_block_time" ]]; then
    echo "   • Block Production: $(classify_block_time $avg_block_time)"
else
    echo "   • Block Production: Unable to assess"
fi

echo "   • L1 Rate Limiting: $l1_rate_limit_status"
echo "   • Consensus Rate Limiting: $cons_rate_limit_status"

# Enhanced block freshness reporting
if [[ "$consensus_functional" == false ]]; then
    echo "   • Block Freshness: CONSENSUS_FAILED"
else
    echo "   • Block Freshness: $block_status"
fi

echo -e "${BLUE}===============================================${NC}"
