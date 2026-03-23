#!/usr/bin/env python3
"""
Smainer Infrastructure Capacity Planning Calculator
Estimates resource requirements for scaling to target provider counts
"""

import argparse
import json
import math
from datetime import datetime, timedelta
from dataclasses import dataclass
from typing import Dict, List, Tuple

@dataclass
class CapacityMetrics:
    """Current baseline capacity measurements"""
    providers_current: int = 150
    
    # Relayer capacity (per instance)
    relayer_cpu_cores: float = 2.0
    relayer_memory_gb: float = 4.0
    relayer_storage_gb: float = 20.0
    relayer_max_connections: int = 1000
    
    # Redis capacity (per node)
    redis_memory_gb: float = 4.0
    redis_ops_per_second: int = 50000
    redis_network_mbps: float = 100
    
    # Database capacity
    postgres_cpu_cores: float = 2.0
    postgres_memory_gb: float = 8.0
    postgres_storage_gb: float = 500
    postgres_connections_max: int = 200
    
    # Network bandwidth
    websocket_bandwidth_kbps_per_provider: float = 50  # 50KB/s per active provider
    p2p_overhead_percentage: float = 20  # 20% overhead for P2P mesh
    
    # Task processing
    tasks_per_second_peak: float = 200
    tasks_per_provider_per_hour: float = 10
    
    # Financial
    monthly_cost_per_relayer_instance: float = 150  # USD
    monthly_cost_per_redis_node: float = 200  # USD
    monthly_cost_per_postgres_gb: float = 2  # USD
    monthly_bandwidth_cost_per_gb: float = 0.1  # USD

def calculate_relayer_requirements(target_providers: int, metrics: CapacityMetrics) -> Dict:
    """Calculate relayer cluster requirements"""
    
    # Connection capacity calculation
    connections_needed = target_providers * 1.2  # 20% overhead for reconnections
    relayer_instances_for_connections = math.ceil(connections_needed / metrics.relayer_max_connections)
    
    # CPU calculation based on task throughput
    expected_tasks_per_second = (target_providers * metrics.tasks_per_provider_per_hour) / 3600
    cpu_utilization_factor = expected_tasks_per_second / metrics.tasks_per_second_peak
    relayer_instances_for_cpu = math.ceil(cpu_utilization_factor * 4)  # 4x safety factor
    
    # Take the maximum of connection and CPU requirements
    required_instances = max(relayer_instances_for_connections, relayer_instances_for_cpu)
    
    # Add high availability requirement (minimum 3 instances)
    if required_instances < 3:
        required_instances = 3
    
    return {
        "instances": required_instances,
        "cpu_per_instance": metrics.relayer_cpu_cores * (1 + cpu_utilization_factor),
        "memory_per_instance_gb": metrics.relayer_memory_gb * (1 + cpu_utilization_factor * 0.5),
        "storage_per_instance_gb": metrics.relayer_storage_gb * math.log10(target_providers / 10),
        "monthly_cost_usd": required_instances * metrics.monthly_cost_per_relayer_instance,
        "bottleneck_factor": "connections" if relayer_instances_for_connections > relayer_instances_for_cpu else "cpu"
    }

def calculate_redis_requirements(target_providers: int, metrics: CapacityMetrics) -> Dict:
    """Calculate Redis cluster requirements"""
    
    # Memory calculation based on active connections and task queues
    memory_per_provider_mb = 10  # 10MB per provider for connection state + queues
    total_memory_gb = (target_providers * memory_per_provider_mb + 2048) / 1024  # +2GB base
    
    # Operations calculation
    ops_per_provider = 50  # Heartbeats + task operations
    total_ops_per_second = target_providers * ops_per_provider
    nodes_for_ops = math.ceil(total_ops_per_second / metrics.redis_ops_per_second)
    
    # Memory-based node calculation
    nodes_for_memory = math.ceil(total_memory_gb / metrics.redis_memory_gb)
    
    # High availability requirement (minimum 6 nodes: 3 masters + 3 replicas)
    required_nodes = max(nodes_for_ops, nodes_for_memory, 6)
    
    return {
        "cluster_nodes": required_nodes,
        "memory_per_node_gb": min(metrics.redis_memory_gb, total_memory_gb / (required_nodes // 2)),
        "total_ops_per_second": total_ops_per_second,
        "monthly_cost_usd": required_nodes * metrics.monthly_cost_per_redis_node,
        "bottleneck_factor": "operations" if nodes_for_ops > nodes_for_memory else "memory"
    }

def calculate_database_requirements(target_providers: int, metrics: CapacityMetrics) -> Dict:
    """Calculate PostgreSQL requirements"""
    
    # Storage calculation based on transparency logs and task history
    logs_per_provider_per_day_mb = 50  # 50MB of transparency logs per provider per day
    task_history_mb_per_provider = 100  # Historical task data
    
    daily_storage_gb = (target_providers * logs_per_provider_per_day_mb) / 1024
    total_storage_gb = metrics.postgres_storage_gb + (daily_storage_gb * 90)  # 90 days retention
    
    # Connection calculation
    connections_needed = min(target_providers // 5, 500)  # Max 500 concurrent connections
    
    # CPU calculation based on query load
    queries_per_second = target_providers * 2  # 2 queries per second per provider
    cpu_scale_factor = max(1.0, queries_per_second / 100)  # Scale CPU for query load
    
    return {
        "cpu_cores": metrics.postgres_cpu_cores * cpu_scale_factor,
        "memory_gb": max(metrics.postgres_memory_gb, math.sqrt(target_providers) * 2),
        "storage_gb": total_storage_gb,
        "max_connections": connections_needed,
        "monthly_storage_cost_usd": total_storage_gb * metrics.monthly_cost_per_postgres_gb,
        "daily_growth_gb": daily_storage_gb
    }

def calculate_network_requirements(target_providers: int, metrics: CapacityMetrics) -> Dict:
    """Calculate network bandwidth requirements"""
    
    # WebSocket bandwidth
    websocket_bandwidth_mbps = (target_providers * metrics.websocket_bandwidth_kbps_per_provider) / 1000
    
    # P2P mesh bandwidth (for decentralized phase)
    p2p_bandwidth_mbps = websocket_bandwidth_mbps * (metrics.p2p_overhead_percentage / 100)
    
    # Blockchain sync bandwidth
    blockchain_bandwidth_mbps = 10  # Constant 10Mbps for Starknet sync
    
    total_bandwidth_mbps = websocket_bandwidth_mbps + p2p_bandwidth_mbps + blockchain_bandwidth_mbps
    
    # Monthly data transfer calculation
    monthly_data_gb = (total_bandwidth_mbps * 0.125 * 3600 * 24 * 30) / 1024  # Convert to GB/month
    
    return {
        "websocket_bandwidth_mbps": websocket_bandwidth_mbps,
        "p2p_bandwidth_mbps": p2p_bandwidth_mbps,
        "blockchain_bandwidth_mbps": blockchain_bandwidth_mbps,
        "total_bandwidth_mbps": total_bandwidth_mbps,
        "monthly_data_gb": monthly_data_gb,
        "monthly_bandwidth_cost_usd": monthly_data_gb * metrics.monthly_bandwidth_cost_per_gb
    }

def generate_migration_timeline(target_providers: int) -> List[Dict]:
    """Generate capacity requirements for each migration phase"""
    
    phases = [
        {"name": "Phase 1: Transparent Hybrid", "days": 30, "providers": target_providers * 0.2},
        {"name": "Phase 2: Selective Decentralization", "days": 60, "providers": target_providers * 0.5},
        {"name": "Phase 3: Full Decentralization", "days": 90, "providers": target_providers}
    ]
    
    timeline = []
    metrics = CapacityMetrics()
    
    for phase in phases:
        providers = int(phase["providers"])
        relayer_req = calculate_relayer_requirements(providers, metrics)
        redis_req = calculate_redis_requirements(providers, metrics)
        db_req = calculate_database_requirements(providers, metrics)
        network_req = calculate_network_requirements(providers, metrics)
        
        total_cost = (relayer_req["monthly_cost_usd"] + 
                     redis_req["monthly_cost_usd"] + 
                     db_req["monthly_storage_cost_usd"] + 
                     network_req["monthly_bandwidth_cost_usd"])
        
        timeline.append({
            "phase": phase["name"],
            "target_date": (datetime.now() + timedelta(days=phase["days"])).strftime("%Y-%m-%d"),
            "target_providers": providers,
            "requirements": {
                "relayer": relayer_req,
                "redis": redis_req,
                "database": db_req,
                "network": network_req
            },
            "monthly_cost_usd": total_cost,
            "cost_per_provider_usd": total_cost / providers
        })
    
    return timeline

def print_capacity_report(target_providers: int, output_format: str = "text"):
    """Generate and print comprehensive capacity planning report"""
    
    metrics = CapacityMetrics()
    timeline = generate_migration_timeline(target_providers)
    
    if output_format == "json":
        print(json.dumps({
            "target_providers": target_providers,
            "baseline_metrics": metrics.__dict__,
            "migration_timeline": timeline
        }, indent=2))
        return
    
    # Text output
    print(f"🚀 SMAINER CAPACITY PLANNING REPORT")
    print(f"Target Providers: {target_providers}")
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    
    for phase_data in timeline:
        print(f"\n📅 {phase_data['phase']}")
        print(f"Target Date: {phase_data['target_date']}")
        print(f"Providers: {phase_data['target_providers']:,}")
        
        req = phase_data['requirements']
        
        print(f"\n🖥️  Relayer Cluster:")
        print(f"  - Instances: {req['relayer']['instances']}")
        print(f"  - CPU per instance: {req['relayer']['cpu_per_instance']:.1f} cores")
        print(f"  - Memory per instance: {req['relayer']['memory_per_instance_gb']:.1f} GB")
        print(f"  - Storage per instance: {req['relayer']['storage_per_instance_gb']:.0f} GB")
        print(f"  - Bottleneck: {req['relayer']['bottleneck_factor']}")
        
        print(f"\n🔧 Redis Cluster:")
        print(f"  - Nodes: {req['redis']['cluster_nodes']}")
        print(f"  - Memory per node: {req['redis']['memory_per_node_gb']:.1f} GB")
        print(f"  - Operations/sec: {req['redis']['total_ops_per_second']:,}")
        print(f"  - Bottleneck: {req['redis']['bottleneck_factor']}")
        
        print(f"\n🗃️  PostgreSQL:")
        print(f"  - CPU cores: {req['database']['cpu_cores']:.1f}")
        print(f"  - Memory: {req['database']['memory_gb']:.1f} GB")
        print(f"  - Storage: {req['database']['storage_gb']:.0f} GB")
        print(f"  - Daily growth: {req['database']['daily_growth_gb']:.1f} GB/day")
        
        print(f"\n🌐 Network:")
        print(f"  - WebSocket: {req['network']['websocket_bandwidth_mbps']:.1f} Mbps")
        print(f"  - P2P overhead: {req['network']['p2p_bandwidth_mbps']:.1f} Mbps")
        print(f"  - Total bandwidth: {req['network']['total_bandwidth_mbps']:.1f} Mbps")
        print(f"  - Monthly data: {req['network']['monthly_data_gb']:.0f} GB")
        
        print(f"\n💰 Cost Estimate:")
        print(f"  - Total monthly: ${phase_data['monthly_cost_usd']:.0f}")
        print(f"  - Cost per provider: ${phase_data['cost_per_provider_usd']:.2f}")
        
        print("-" * 60)
    
    # Summary recommendations
    final_phase = timeline[-1]
    print(f"\n🎯 SUMMARY RECOMMENDATIONS")
    print(f"Final Monthly Cost: ${final_phase['monthly_cost_usd']:.0f}")
    print(f"Cost per Provider: ${final_phase['cost_per_provider_usd']:.2f}")
    
    # Identify critical bottlenecks
    bottlenecks = []
    req = final_phase['requirements']
    if req['relayer']['bottleneck_factor'] == 'connections':
        bottlenecks.append("WebSocket connection limits")
    if req['redis']['bottleneck_factor'] == 'operations':
        bottlenecks.append("Redis operations throughput")
    
    if bottlenecks:
        print(f"\n⚠️  Critical Bottlenecks: {', '.join(bottlenecks)}")
        print("Consider scaling these components first")
    
    print(f"\n🔄 Infrastructure Automation Required:")
    print(f"  - Auto-scaling groups for relayer instances")
    print(f"  - Redis cluster automatic failover")
    print(f"  - Database connection pooling and read replicas")
    print(f"  - Network bandwidth monitoring and alerting")

def main():
    parser = argparse.ArgumentParser(description="Smainer Infrastructure Capacity Planning")
    parser.add_argument("target_providers", type=int, help="Target number of providers")
    parser.add_argument("--format", choices=["text", "json"], default="text", 
                       help="Output format (default: text)")
    parser.add_argument("--baseline-providers", type=int, default=150,
                       help="Current baseline provider count")
    
    args = parser.parse_args()
    
    if args.target_providers <= 0:
        print("Error: target_providers must be positive")
        return 1
    
    if args.target_providers < args.baseline_providers:
        print(f"Warning: target_providers ({args.target_providers}) is less than baseline ({args.baseline_providers})")
    
    print_capacity_report(args.target_providers, args.format)
    return 0

if __name__ == "__main__":
    exit(main())