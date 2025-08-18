#!/usr/bin/env python3
"""
Terraform DAG Orchestration Script
Executes Terraform layers in dependency order with parallel execution capabilities
"""

import os
import sys
import subprocess
import argparse
import json
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import List, Dict, Set, Optional
from dataclasses import dataclass
from enum import Enum

class LayerStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    SUCCESS = "success"
    FAILED = "failed"
    SKIPPED = "skipped"

@dataclass
class Layer:
    name: str
    path: str
    dependencies: List[str]
    status: LayerStatus = LayerStatus.PENDING
    start_time: Optional[float] = None
    end_time: Optional[float] = None
    error_message: Optional[str] = None

class TerraformDAG:
    def __init__(self, environment: str, region: str, action: str, auto_approve: bool = False):
        self.environment = environment
        self.region = region
        self.action = action
        self.auto_approve = auto_approve
        self.layers: Dict[str, Layer] = {}
        self.execution_log: List[Dict] = []
        
        # Define DAG structure
        self._define_layers()
    
    def _define_layers(self):
        """Define the DAG structure with layers and their dependencies"""
        layer_definitions = [
            # Governance Layer (Level 0)
            Layer("governance-providers", "00-governance/providers", []),
            Layer("governance-iam", "00-governance/iam", ["governance-providers"]),
            Layer("governance-organization", "00-governance/organization", ["governance-providers"]),
            
            # Core Layer (Level 1)
            Layer("core-networking", "01-core/01-networking", ["governance-iam", "governance-organization"]),
            Layer("core-security", "01-core/02-security", ["core-networking"]),
            Layer("core-routing", "01-core/03-routing", ["core-networking"]),
            
            # Services Layer (Level 2)
            Layer("services-databases", "02-services/01-databases", ["core-security", "core-routing"]),
            Layer("services-caching", "02-services/02-caching", ["core-security", "core-routing"]),
            Layer("services-messaging", "02-services/03-messaging", ["core-security", "core-routing"]),
            Layer("services-ci-cd", "02-services/04-ci-cd", ["core-security", "core-routing"]),
            
            # Applications Layer (Level 3)
            Layer("app-1", "03-applications/app-1", ["services-databases", "services-caching"]),
            Layer("app-2", "03-applications/app-2", ["services-databases", "services-messaging"]),
        ]
        
        for layer in layer_definitions:
            self.layers[layer.name] = layer
    
    def _layer_exists(self, layer: Layer) -> bool:
        """Check if layer directory exists and has Terraform files"""
        layer_path = Path(layer.path)
        if not layer_path.exists():
            return False
        
        tf_files = list(layer_path.glob("*.tf"))
        return len(tf_files) > 0
    
    def _get_tfvars_file(self, layer_path: str) -> Optional[str]:
        """Get the appropriate tfvars file for the layer"""
        env_tfvars = f"{layer_path}/environments/{self.environment}.tfvars"
        legacy_tfvars = f"{layer_path}/settings.auto.tfvars"
        
        if os.path.exists(env_tfvars):
            return f"environments/{self.environment}.tfvars"
        elif os.path.exists(legacy_tfvars):
            return "settings.auto.tfvars"
        
        return None
    
    def _execute_terraform(self, layer: Layer) -> bool:
        """Execute Terraform command for a specific layer"""
        if not self._layer_exists(layer):
            layer.status = LayerStatus.SKIPPED
            self._log(f"⚠️  Skipped {layer.name}: Directory or Terraform files not found")
            return True
        
        layer.status = LayerStatus.RUNNING
        layer.start_time = time.time()
        
        try:
            original_dir = os.getcwd()
            os.chdir(layer.path)
            
            # Initialize Terraform
            if not os.path.exists(".terraform"):
                self._log(f"🔧 Initializing Terraform in {layer.name}")
                result = subprocess.run(["terraform", "init"], 
                                      capture_output=True, text=True, check=True)
            
            # Prepare command arguments
            cmd = ["terraform", self.action]
            
            # Add auto-approve for apply/destroy
            if self.auto_approve and self.action in ["apply", "destroy"]:
                cmd.append("-auto-approve")
            
            # Add variables
            cmd.extend([
                f"-var=environment={self.environment}",
                f"-var=region={self.region}"
            ])
            
            # Add tfvars file if exists
            tfvars_file = self._get_tfvars_file(layer.path)
            if tfvars_file:
                cmd.append(f"-var-file={tfvars_file}")
            
            # Execute Terraform command
            self._log(f"🚀 Executing: {' '.join(cmd)} in {layer.name}")
            
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            
            layer.status = LayerStatus.SUCCESS
            layer.end_time = time.time()
            duration = layer.end_time - layer.start_time
            
            self._log(f"✅ Successfully completed {layer.name} in {duration:.2f}s")
            
            # Log execution details
            self.execution_log.append({
                "layer": layer.name,
                "action": self.action,
                "status": "success",
                "duration": duration,
                "timestamp": time.time()
            })
            
            return True
            
        except subprocess.CalledProcessError as e:
            layer.status = LayerStatus.FAILED
            layer.end_time = time.time()
            layer.error_message = e.stderr
            
            duration = layer.end_time - layer.start_time if layer.start_time else 0
            self._log(f"❌ Failed {layer.name} after {duration:.2f}s: {e.stderr}")
            
            # Log execution details
            self.execution_log.append({
                "layer": layer.name,
                "action": self.action,
                "status": "failed",
                "duration": duration,
                "error": e.stderr,
                "timestamp": time.time()
            })
            
            return False
            
        except Exception as e:
            layer.status = LayerStatus.FAILED
            layer.error_message = str(e)
            self._log(f"❌ Unexpected error in {layer.name}: {str(e)}")
            return False
            
        finally:
            os.chdir(original_dir)
    
    def _get_ready_layers(self) -> List[Layer]:
        """Get layers that are ready to execute (all dependencies completed)"""
        ready = []
        
        for layer in self.layers.values():
            if layer.status != LayerStatus.PENDING:
                continue
            
            # Check if all dependencies are successful or skipped
            dependencies_ready = True
            for dep_name in layer.dependencies:
                dep_layer = self.layers.get(dep_name)
                if not dep_layer or dep_layer.status not in [LayerStatus.SUCCESS, LayerStatus.SKIPPED]:
                    dependencies_ready = False
                    break
            
            if dependencies_ready:
                ready.append(layer)
        
        return ready
    
    def _log(self, message: str):
        """Log message with timestamp"""
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {message}")
    
    def execute_sequential(self) -> bool:
        """Execute layers sequentially in dependency order"""
        self._log(f"🎯 Starting sequential execution for {self.environment} environment")
        
        total_layers = len([l for l in self.layers.values() if self._layer_exists(l)])
        completed = 0
        
        while completed < total_layers:
            ready_layers = self._get_ready_layers()
            
            if not ready_layers:
                # Check if we have failed layers
                failed_layers = [l for l in self.layers.values() if l.status == LayerStatus.FAILED]
                if failed_layers:
                    self._log(f"❌ Execution stopped due to failed layers: {[l.name for l in failed_layers]}")
                    return False
                break
            
            # Execute one layer at a time
            layer = ready_layers[0]
            success = self._execute_terraform(layer)
            
            if not success:
                return False
            
            if layer.status in [LayerStatus.SUCCESS, LayerStatus.SKIPPED]:
                completed += 1
        
        self._log("🎉 Sequential execution completed successfully!")
        return True
    
    def execute_parallel(self, max_workers: int = 3) -> bool:
        """Execute layers in parallel where possible"""
        self._log(f"🎯 Starting parallel execution with {max_workers} workers for {self.environment} environment")
        
        total_layers = len([l for l in self.layers.values() if self._layer_exists(l)])
        completed = 0
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            while completed < total_layers:
                ready_layers = self._get_ready_layers()
                
                if not ready_layers:
                    # Check if we have failed layers
                    failed_layers = [l for l in self.layers.values() if l.status == LayerStatus.FAILED]
                    if failed_layers:
                        self._log(f"❌ Execution stopped due to failed layers: {[l.name for l in failed_layers]}")
                        return False
                    break
                
                # Submit ready layers for parallel execution
                future_to_layer = {
                    executor.submit(self._execute_terraform, layer): layer 
                    for layer in ready_layers
                }
                
                # Wait for at least one to complete
                for future in as_completed(future_to_layer):
                    layer = future_to_layer[future]
                    success = future.result()
                    
                    if not success:
                        return False
                    
                    if layer.status in [LayerStatus.SUCCESS, LayerStatus.SKIPPED]:
                        completed += 1
        
        self._log("🎉 Parallel execution completed successfully!")
        return True
    
    def validate_dependencies(self) -> bool:
        """Validate that the DAG has no circular dependencies"""
        self._log("🔍 Validating DAG dependencies...")
        
        visited = set()
        rec_stack = set()
        
        def has_cycle(layer_name: str) -> bool:
            if layer_name in rec_stack:
                return True
            if layer_name in visited:
                return False
            
            visited.add(layer_name)
            rec_stack.add(layer_name)
            
            layer = self.layers.get(layer_name)
            if layer:
                for dep in layer.dependencies:
                    if has_cycle(dep):
                        return True
            
            rec_stack.remove(layer_name)
            return False
        
        for layer_name in self.layers:
            if layer_name not in visited:
                if has_cycle(layer_name):
                    self._log(f"❌ Circular dependency detected involving {layer_name}")
                    return False
        
        self._log("✅ DAG validation passed - no circular dependencies")
        return True
    
    def generate_execution_plan(self) -> List[List[str]]:
        """Generate execution plan showing parallel execution groups"""
        plan = []
        remaining = set(self.layers.keys())
        
        while remaining:
            # Find layers with no dependencies in remaining set
            current_group = []
            for layer_name in remaining:
                layer = self.layers[layer_name]
                if all(dep not in remaining for dep in layer.dependencies):
                    current_group.append(layer_name)
            
            if not current_group:
                break  # Should not happen if DAG is valid
            
            plan.append(current_group)
            remaining -= set(current_group)
        
        return plan
    
    def print_execution_plan(self):
        """Print the execution plan"""
        plan = self.generate_execution_plan()
        
        self._log("📋 Execution Plan:")
        for i, group in enumerate(plan):
            if len(group) == 1:
                self._log(f"  Level {i}: {group[0]}")
            else:
                self._log(f"  Level {i}: {group} (parallel)")
    
    def print_summary(self):
        """Print execution summary"""
        self._log("\n📊 Execution Summary:")
        
        status_counts = {}
        total_duration = 0
        
        for layer in self.layers.values():
            status = layer.status.value
            status_counts[status] = status_counts.get(status, 0) + 1
            
            if layer.start_time and layer.end_time:
                duration = layer.end_time - layer.start_time
                total_duration += duration
                self._log(f"  {layer.name}: {status} ({duration:.2f}s)")
            else:
                self._log(f"  {layer.name}: {status}")
        
        self._log(f"\nTotal execution time: {total_duration:.2f}s")
        self._log(f"Status summary: {status_counts}")

def main():
    parser = argparse.ArgumentParser(description="Terraform DAG Orchestration")
    parser.add_argument("environment", help="Target environment (dev, stg, prd)")
    parser.add_argument("--region", default="us-east-1", help="AWS region")
    parser.add_argument("--action", choices=["plan", "apply", "destroy"], 
                       default="plan", help="Terraform action")
    parser.add_argument("--auto-approve", action="store_true", 
                       help="Auto-approve apply/destroy operations")
    parser.add_argument("--parallel", action="store_true", 
                       help="Use parallel execution")
    parser.add_argument("--max-workers", type=int, default=3, 
                       help="Maximum parallel workers")
    parser.add_argument("--validate-only", action="store_true", 
                       help="Only validate dependencies")
    parser.add_argument("--show-plan", action="store_true", 
                       help="Show execution plan and exit")
    
    args = parser.parse_args()
    
    # Create DAG orchestrator
    dag = TerraformDAG(
        environment=args.environment,
        region=args.region,
        action=args.action,
        auto_approve=args.auto_approve
    )
    
    # Validate dependencies
    if not dag.validate_dependencies():
        sys.exit(1)
    
    # Show execution plan if requested
    if args.show_plan:
        dag.print_execution_plan()
        sys.exit(0)
    
    # Validate only if requested
    if args.validate_only:
        print("✅ DAG validation completed successfully")
        sys.exit(0)
    
    # Execute
    try:
        if args.parallel:
            success = dag.execute_parallel(max_workers=args.max_workers)
        else:
            success = dag.execute_sequential()
        
        dag.print_summary()
        
        if not success:
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n⚠️  Execution interrupted by user")
        dag.print_summary()
        sys.exit(1)

if __name__ == "__main__":
    main()