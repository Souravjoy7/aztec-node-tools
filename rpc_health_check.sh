#!/bin/bash

# Enhanced RPC Health Check Script with NODE-Standard Classifications
# Version 3.0 - Accurate thresholds, consensus RPC rate limiting, comprehensive testing

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}🏥 NODE-STANDARD RPC HEALTH CHECK SYSTEM${NC}"
echo -e "${BLUE}By SOUROV JOY - Accurate Performance Standards${NC}"
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
        sum=$(echo "$sum + $value" | bc -l 2>/dev/null || echo "$sum + $value" | awk '{print $1 + $3}')
    done
    
    if command -v bc >/dev/null 2>&1; then
        echo "scale=4; $sum / $count" | bc -l
    else
        awk -v s="$sum" -v c="$count" 'BEGIN {printf "%.4f", s/c}'
    fi
}

# Industry-standard latency classification (corrected thresholds)
classify_latency() {
    local latency=$1
    local latency_ms
    
    # Convert to milliseconds for easier comparison
    if command -v bc >/dev/null 2>&1; then
        latency_ms=$(echo "scale=2; $latency * 1000" | bc -l)
        
        if (( $(echo "$latency == 0" | bc -l) )); then
            echo "❌ Invalid"
        elif (( $(echo "$latency_ms < 25" | bc -l) )); then
            echo "🚀 Excellent"
        elif (( $(echo "$latency_ms < 50" | bc -l) )); then
            echo "✅ Good"
        elif (( $(echo "$latency_ms < 200" | bc -l) )); then
            echo "⚡ Acceptable"
        elif (( $(echo "$latency_ms < 500" | bc -l) )); then
            echo "⚠️ Slow"
        else
            echo "❌ Very Slow"
        fi
    else
        # Fallback without bc
        if awk -v l="$latency" 'BEGIN {exit (l == 0)}'; then
            echo "❌ Invalid"
        elif awk -v l="$latency" 'BEGIN {exit (l >= 0.025)}'; then
            echo "🚀 Excellent"
        elif awk -v l="$latency" 'BEGIN {exit (l >= 0.05)}'; then
            echo "✅ Good"
        elif awk -v l="$latency" 'BEGIN {exit (l >= 0.2)}'; then
            echo "⚡ Acceptable"
        elif awk -v l="$latency" 'BEGIN {exit (l >= 0.5)}'; then
            echo "⚠️ Slow"
        else
            echo "❌ Very Slow"
        fi
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
        printf "  L1 Request %d/%d...\r" $i $consecutive_requests
        
        # Use curl with detailed response capture
        response=$(curl -s -w "HTTPCODE:%{http_code}\nTIME:%{time_total}" \
            -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
            "$url" 2>/dev/null)
        
        # Extract metrics
        http_code=$(echo "$response" | grep "HTTPCODE:" | cut -d: -f2)
        response_time=$(echo "$response" | grep "TIME:" | cut -d: -f2)
        json_response=$(echo "$response" | sed '/HTTPCODE:/,$d')
        
        request_times+=($response_time)
        status_codes+=($http_code)
        
        # Check for rate limiting indicators
        if [[ "$http_code" == "429" ]] || [[ "$http_code" == "503" ]] || [[ "$http_code" == "402" ]] || [[ "$http_code" == "403" ]]; then
            limit_detected=true
            echo -e "\n${RED}⚠️ L1 Rate limit detected via HTTP $http_code on request $i${NC}"
        fi
        
        # JSON-RPC error detection
        if command -v jq >/dev/null 2>&1 && echo "$json_response" | jq -e '.error.code' >/dev/null 2>&1; then
            error_code=$(echo "$json_response" | jq -r '.error.code')
            error_message=$(echo "$json_response" | jq -r '.error.message')
            
            if [[ "$error_code" == "-32029" ]] || [[ "$error_code" == "-33000" ]] || [[ "$error_code" == "-33200" ]] || [[ "$error_code" == "-32005" ]]; then
                limit_detected=true
                echo -e "\n${RED}⚠️ L1 Rate limit detected via JSON-RPC error $error_code: $error_message${NC}"
                json_errors+=("$error_code")
            fi
        fi
        
        sleep 0.1
    done
    
    echo # New line
    
    # Statistical analysis
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
    
    # Final assessment
    if [ "$limit_detected" = true ]; then
        echo -e "${RED}🔴 L1 Rate Limiting: DETECTED${NC}"
        l1_rate_limit_status="DETECTED"
        l1_rate_limit_details="HTTP codes: ${status_codes[*]}, JSON errors: ${json_errors[*]}"
    elif command -v bc >/dev/null 2>&1 && (( $(echo "$failure_rate > 20" | bc -l) )); then
        echo -e "${YELLOW}🟡 L1 Rate Limiting: LIKELY (${failure_rate}% failure rate)${NC}"
        l1_rate_limit_status="LIKELY"
        l1_rate_limit_details="High failure rate: ${failure_rate}%"
    elif command -v bc >/dev/null 2>&1 && (( $(echo "$avg_time > 3.0" | bc -l) )); then
        echo -e "${YELLOW}🟡 L1 Rate Limiting: POSSIBLE (Avg response: ${avg_time}s)${NC}"
        l1_rate_limit_status="POSSIBLE"
        l1_rate_limit_details="Slow average response time"
    else
        echo -e "${GREEN}🟢 L1 Rate Limiting: NONE DETECTED${NC}"
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
    local json_errors=()
    
    echo -e "${PURPLE}🚦 Testing Consensus RPC rate limiting (${consecutive_requests} requests)...${NC}"
    
    # Test various consensus endpoints
    local endpoints=(
        "/eth/v1/node/health"
        "/eth/v1/beacon/headers/head"
        "/eth/v1/node/syncing"
        "/eth/v1/node/identity"
        "/eth/v1/beacon/headers/finalized"
    )
    
    for ((i=1; i<=consecutive_requests; i++)); do
        printf "  Consensus Request %d/%d...\r" $i $consecutive_requests
        
        # Rotate through different endpoints to test comprehensive rate limiting
        local endpoint_index=$((i % ${#endpoints[@]}))
        local test_endpoint="${endpoints[$endpoint_index]}"
        
        response=$(curl -s -w "HTTPCODE:%{http_code}\nTIME:%{time_total}" \
            -H "Accept: application/json" \
            "$url$test_endpoint" 2>/dev/null)
        
        # Extract metrics
        http_code=$(echo "$response" | grep "HTTPCODE:" | cut -d: -f2)
        response_time=$(echo "$response" | grep "TIME:" | cut -d: -f2)
        json_response=$(echo "$response" | sed '/HTTPCODE:/,$d')
        
        request_times+=($response_time)
        status_codes+=($http_code)
        
        # Check for rate limiting indicators
        if [[ "$http_code" == "429" ]] || [[ "$http_code" == "503" ]] || [[ "$http_code" == "402" ]] || [[ "$http_code" == "403" ]]; then
            limit_detected=true
            echo -e "\n${RED}⚠️ Consensus Rate limit detected via HTTP $http_code on request $i (endpoint: $test_endpoint)${NC}"
        fi
        
        # Check for error responses in JSON
        if command -v jq >/dev/null 2>&1 && echo "$json_response" | jq -e '.code' >/dev/null 2>&1; then
            error_code=$(echo "$json_response" | jq -r '.code')
            error_message=$(echo "$json_response" | jq -r '.message // empty')
            
            if [[ "$error_code" == "429" ]] || [[ "$error_code" == "503" ]]; then
                limit_detected=true
                echo -e "\n${RED}⚠️ Consensus Rate limit detected via JSON error $error_code: $error_message${NC}"
                json_errors+=("$error_code")
            fi
        fi
        
        sleep 0.1
    done
    
    echo # New line
    
    # Statistical analysis
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
    
    # Final assessment
    if [ "$limit_detected" = true ]; then
        echo -e "${RED}🔴 Consensus Rate Limiting: DETECTED${NC}"
        cons_rate_limit_status="DETECTED"
        cons_rate_limit_details="HTTP codes: ${status_codes[*]}, JSON errors: ${json_errors[*]}"
    elif command -v bc >/dev/null 2>&1 && (( $(echo "$failure_rate > 20" | bc -l) )); then
        echo -e "${YELLOW}🟡 Consensus Rate Limiting: LIKELY (${failure_rate}% failure rate)${NC}"
        cons_rate_limit_status="LIKELY"
        cons_rate_limit_details="High failure rate: ${failure_rate}%"
    elif command -v bc >/dev/null 2>&1 && (( $(echo "$avg_time > 3.0" | bc -l) )); then
        echo -e "${YELLOW}🟡 Consensus Rate Limiting: POSSIBLE (Avg response: ${avg_time}s)${NC}"
        cons_rate_limit_status="POSSIBLE"
        cons_rate_limit_details="Slow average response time"
    else
        echo -e "${GREEN}🟢 Consensus Rate Limiting: NONE DETECTED${NC}"
        cons_rate_limit_status="NONE"
        cons_rate_limit_details="All tests passed"
    fi
    
    echo -e "${PURPLE}📈 Consensus Statistics: Avg time: ${avg_time}s, Failure rate: ${failure_rate}%${NC}"
}

# Block production rate classification
classify_block_time() {
    local block_time=$1
    local expected_time=12.0  # Ethereum average block time
    
    if command -v bc >/dev/null 2>&1; then
        if (( $(echo "$block_time == 0" | bc -l) )); then
            echo "❌ Invalid"
        elif (( $(echo "$block_time < $expected_time * 0.8" | bc -l) )); then
            echo "🚀 Excellent"
        elif (( $(echo "$block_time <= $expected_time * 1.2" | bc -l) )); then
            echo "✅ Good"
        elif (( $(echo "$block_time <= $expected_time * 1.5" | bc -l) )); then
            echo "⚠️ Slow"
        else
            echo "❌ Very Slow"
        fi
    else
        # Fallback without bc
        if awk -v bt="$block_time" 'BEGIN {exit (bt != 0)}'; then
            echo "❌ Invalid"
        elif awk -v bt="$block_time" -v et="$expected_time" 'BEGIN {exit (bt >= et * 0.8)}'; then
            echo "🚀 Excellent"
        elif awk -v bt="$block_time" -v et="$expected_time" 'BEGIN {exit (bt > et * 1.2)}'; then
            echo "✅ Good"
        elif awk -v bt="$block_time" -v et="$expected_time" 'BEGIN {exit (bt > et * 1.5)}'; then
            echo "⚠️ Slow"
        else
            echo "❌ Very Slow"
        fi
    fi
}

# Calculate final verdict score with corrected thresholds
calculate_verdict() {
    local score=0
    
    # L1 RPC Response Time (35 points) - Updated thresholds
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
        # Simplified scoring without bc
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
        score=$((score + 15))  # Default moderate score
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
    
    # Block freshness (5 points)
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

# Detect rate limiting for both L1 and Consensus
detect_l1_rate_limit "$RPC_URL"
echo
detect_consensus_rate_limit "$CONS_URL"

# Perform 5 measurements for averaging
echo -e "\n${GREEN}📊 Collecting 5 measurements for accurate assessment...${NC}"

for ((i=1; i<=5; i++)); do
    echo -e "  ${BLUE}📈 Measurement $i/5...${NC}"
    
    # Measure L1 RPC response time
    rpc_time=$(curl -s -o /dev/null -w "%{time_total}" -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' "$RPC_URL" 2>/dev/null || echo "0")
    rpc_times+=($rpc_time)
    
    # Measure Consensus RPC response time
    cons_time=$(curl -s -o /dev/null -w "%{time_total}" "$CONS_URL/eth/v1/node/health" 2>/dev/null || echo "0")
    cons_rpc_times+=($cons_time)
    
    # Get block information for production rate calculation
    current_block=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}' "$RPC_URL" 2>/dev/null)
    
    if command -v jq >/dev/null 2>&1; then
        current_block_hex=$(echo "$current_block" | jq -r .result.number 2>/dev/null)
        current_timestamp_hex=$(echo "$current_block" | jq -r .result.timestamp 2>/dev/null)
    else
        current_block_hex=$(echo "$current_block" | grep -o '"number":"[^"]*"' | cut -d'"' -f4)
        current_timestamp_hex=$(echo "$current_block" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
    fi
    
    if [[ $current_block_hex != "null" && -n $current_block_hex && $current_block_hex != "" ]]; then
        current_block_dec=$((16#${current_block_hex:2}))
        current_ts_dec=$((16#${current_timestamp_hex:2}))
        
        # Get previous block for time calculation
        prev_block_num=$((current_block_dec - 10))
        prev_block_hex=$(printf '0x%x' $prev_block_num)
        prev_block=$(curl -s -X POST -H "Content-Type: application/json" \
            --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$prev_block_hex\", false],\"id\":1}" "$RPC_URL" 2>/dev/null)
        
        if command -v jq >/dev/null 2>&1; then
            prev_timestamp_hex=$(echo "$prev_block" | jq -r .result.timestamp 2>/dev/null)
        else
            prev_timestamp_hex=$(echo "$prev_block" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
        fi
        
        if [[ $prev_timestamp_hex != "null" && -n $prev_timestamp_hex && $prev_timestamp_hex != "" ]]; then
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

if [[ $block_hex == "null" || -z $block_hex || $block_hex == "" ]]; then
    echo -e "${RED}❌ L1 RPC not producing blocks.${NC}"
    exit 1
fi

block_dec=$((16#${block_hex:2}))
ts_dec=$((16#${timestamp_hex:2}))
now=$(date +%s)
age=$((now - ts_dec))

[[ $age -gt 30 ]] && block_status="⚠️ STALE" || block_status="🟢 FRESH"

# Get finalized block
finalized_block=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["finalized", false],"id":1}' "$RPC_URL" 2>/dev/null)
if command -v jq >/dev/null 2>&1; then
    finalized_block_hex=$(echo "$finalized_block" | jq -r .result.number 2>/dev/null)
else
    finalized_block_hex=$(echo "$finalized_block" | grep -o '"number":"[^"]*"' | cut -d'"' -f4)
fi

# Get consensus metrics
if command -v jq >/dev/null 2>&1; then
    beacon_finalized=$(curl -s "$CONS_URL/eth/v1/beacon/headers/finalized" 2>/dev/null | jq -r '.data.header.message.slot' 2>/dev/null || echo "null")
    beacon_head=$(curl -s "$CONS_URL/eth/v1/beacon/headers/head" 2>/dev/null | jq -r '.data.header.message.slot' 2>/dev/null || echo "null")
    syncing=$(curl -s "$CONS_URL/eth/v1/node/syncing" 2>/dev/null | jq -r '.data.is_syncing' 2>/dev/null || echo "unknown")
    client_id=$(curl -s "$CONS_URL/eth/v1/node/identity" 2>/dev/null | jq -r '.data.client_name' 2>/dev/null || echo "unknown")
    peers=$(curl -s "$CONS_URL/eth/v1/node/identity" 2>/dev/null | jq -r '.data.peer_count' 2>/dev/null || echo "0")
else
    beacon_finalized="unavailable"
    beacon_head="unavailable" 
    syncing="unknown"
    client_id="unknown"
    peers="0"
fi

# Calculate final verdict
final_score=$(calculate_verdict)

# Display results
echo -e "\n" 
echo -e "${BLUE}===============================================================${NC}"
echo -e "${BLUE}🏥 NODE-STANDARD RPC HEALTH CHECK RESULTS SCRIPT BY SOUROV JOY${NC}"
echo -e "${BLUE}===============================================================${NC}"

echo -e "\n${GREEN}📊 BASIC METRICS:${NC}"
if [[ "$chain_id" != "null" && -n "$chain_id" && "$chain_id" != "unknown" ]]; then
    echo "🌐 Chain ID: $((16#${chain_id:2}))"
else
    echo "🌐 Chain ID: Unable to determine"
fi
echo "🔍 Client: $client"
echo "📦 Latest Block: $block_dec | ⏱ Age: ${age}s => $block_status"
if [[ "$finalized_block_hex" != "null" && -n "$finalized_block_hex" && "$finalized_block_hex" != "" ]]; then
    echo "✅ Finalized Block: $((16#${finalized_block_hex:2}))"
else
    echo "❌ Finality not supported"
fi

echo -e "\n${GREEN}⚡ PERFORMANCE METRICS (Node Standards - 5-sample average):${NC}"
printf "🚀 L1 RPC Response Time: %.4f sec (%.1fms) => %s\n" $avg_rpc_time $(echo "scale=1; $avg_rpc_time * 1000" | bc -l 2>/dev/null || echo "N/A") "$(classify_latency $avg_rpc_time)"
printf "🏗️ Consensus RPC Time: %.4f sec (%.1fms) => %s\n" $avg_cons_time $(echo "scale=1; $avg_cons_time * 1000" | bc -l 2>/dev/null || echo "N/A") "$(classify_latency $avg_cons_time)"
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
[[ "$beacon_finalized" != "null" && "$beacon_finalized" != "unavailable" ]] && echo "🏁 Beacon Finalized Slot: $beacon_finalized" || echo "❌ No Beacon Finality"
[[ "$beacon_head" != "null" && "$beacon_head" != "unavailable" ]] && echo "📈 Beacon Head Slot: $beacon_head" || echo "❌ No Beacon Head"
[[ "$syncing" == "false" ]] && echo "✅ Consensus Node is Synced" || echo "🔄 Consensus Node Syncing: $syncing"
echo "🧩 Consensus Client: $client_id | Peers: $peers"

# Industry Standards Reference
echo -e "\n${BLUE}📚 NODE PERFORMANCE STANDARDS:${NC}"
echo "🚀 Excellent: < 25ms (0.025s) - Premium tier performance"
echo "✅ Good: 25-50ms (0.025-0.05s) - Production ready"
echo "⚡ Acceptable: 50-200ms (0.05-0.2s) - Standard performance"
echo "⚠️ Slow: 200-500ms (0.2-0.5s) - Needs optimization"
echo "❌ Very Slow: > 500ms (0.5s+) - Critical performance issues"

# Final Verdict
echo -e "\n" 
echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}🏆 FINAL VERDICT (Node Standards)${NC}"
echo -e "${BLUE}===============================================${NC}"
printf "${GREEN}📊 Overall Score: %d/100${NC}\n" $final_score

if [[ $final_score -ge 90 ]]; then
    echo -e "${GREEN}🥇 VERDICT: BEST FOR NODE${NC}"
    echo -e "${GREEN}   ⭐ Premium-grade performance meeting node excellence standards${NC}"
elif [[ $final_score -ge 75 ]]; then
    echo -e "${YELLOW}🥈 VERDICT: GOOD FOR NODE${NC}"
    echo -e "${YELLOW}   ✅ Production-ready performance with industry-standard metrics${NC}"
elif [[ $final_score -ge 60 ]]; then
    echo -e "${YELLOW}🥉 VERDICT: ACCEPTABLE FOR NODE${NC}"
    echo -e "${YELLOW}   ⚡ Meets basic requirements but has room for improvement${NC}"
else
    echo -e "${RED}❌ VERDICT: WORST FOR NODE${NC}"
    echo -e "${RED}   🚨 Performance issues requiring immediate attention${NC}"
fi

echo -e "\n${BLUE}📝 DETAILED BREAKDOWN:${NC}"
echo "   • L1 RPC Performance: $(classify_latency $avg_rpc_time)"
echo "   • Consensus RPC Performance: $(classify_latency $avg_cons_time)"
if [[ "$avg_block_time" != "0" && -n "$avg_block_time" ]]; then
    echo "   • Block Production: $(classify_block_time $avg_block_time)"
else
    echo "   • Block Production: Unable to assess"
fi
echo "   • L1 Rate Limiting: $l1_rate_limit_status"
echo "   • Consensus Rate Limiting: $cons_rate_limit_status"
echo "   • Block Freshness: $block_status"

echo -e "${BLUE}===============================================${NC}"

# Save results with industry standards
if [[ "$1" == "--save" ]]; then
    timestamp=$(date +"%Y%m%d_%H%M%S")
    report_file="node_standard_rpc_report_${timestamp}.txt"
    
    {
        echo "Node-Standard RPC Health Check Report - $(date)"
        echo "======================================================================"
        echo "L1 RPC URL: $RPC_URL"
        echo "Consensus URL: $CONS_URL"
        echo "Overall Score: $final_score/100"
        echo "Verdict: $(if [[ $final_score -ge 90 ]]; then echo "BEST FOR NODE"; elif [[ $final_score -ge 75 ]]; then echo "GOOD FOR NODE"; elif [[ $final_score -ge 60 ]]; then echo "ACCEPTABLE FOR NODE"; else echo "WORST FOR NODE"; fi)"
        echo "L1 Average RPC Time: ${avg_rpc_time}s ($(echo "scale=1; $avg_rpc_time * 1000" | bc -l 2>/dev/null || echo "N/A")ms)"
        echo "Consensus Average RPC Time: ${avg_cons_time}s ($(echo "scale=1; $avg_cons_time * 1000" | bc -l 2>/dev/null || echo "N/A")ms)"
        echo "Average Block Time: ${avg_block_time}s"
        echo "L1 Rate Limiting: $l1_rate_limit_status"
        echo "Consensus Rate Limiting: $cons_rate_limit_status"
        echo "Block Age: ${age}s"
        echo ""
        echo "Industry Standards Applied:"
        echo "- Excellent: < 25ms | Good: 25-50ms | Acceptable: 50-200ms"
        echo "- Slow: 200-500ms | Very Slow: > 500ms"
    } > "$report_file"
    
    echo -e "\n${GREEN}📄 node-standard report saved to: $report_file${NC}"
fi
