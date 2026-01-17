#!/usr/bin/env python3
"""Extract IoT certificates from Terraform output."""

import json
import subprocess
import sys
import urllib.request
from pathlib import Path


def run_terraform_output(output_name: str, terraform_dir: Path) -> dict:
    """Run terraform output and return parsed JSON."""
    result = subprocess.run(
        ["terraform", "output", "-json", output_name],
        capture_output=True,
        text=True,
        cwd=terraform_dir
    )
    if result.returncode != 0:
        print(f"Error getting {output_name}: {result.stderr}")
        sys.exit(1)
    return json.loads(result.stdout)


def main():
    script_dir = Path(__file__).parent.resolve()
    project_root = script_dir.parent
    terraform_dir = project_root / "terraform"
    certs_dir = project_root / "simulator" / "certs"

    certs_dir.mkdir(parents=True, exist_ok=True)

    # Extract certificates
    print("Extracting certificates from Terraform output...")

    cert_pems = run_terraform_output("iot_certificate_pems", terraform_dir)
    private_keys = run_terraform_output("iot_certificate_private_keys", terraform_dir)

    for vehicle_id, cert_pem in cert_pems.items():
        cert_path = certs_dir / f"{vehicle_id}.cert.pem"
        cert_path.write_text(cert_pem)
        print(f"  Created: {cert_path.name}")

    for vehicle_id, private_key in private_keys.items():
        key_path = certs_dir / f"{vehicle_id}.private.key"
        key_path.write_text(private_key)
        print(f"  Created: {key_path.name}")

    # Download Amazon Root CA
    print("\nDownloading Amazon Root CA...")
    ca_url = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"
    ca_path = certs_dir / "AmazonRootCA1.pem"
    urllib.request.urlretrieve(ca_url, ca_path)
    print(f"  Created: {ca_path.name}")

    # Get IoT endpoint
    endpoint = run_terraform_output("iot_endpoint", terraform_dir)
    print(f"\n{'='*60}")
    print(f"IoT Endpoint: {endpoint}")
    print(f"{'='*60}")
    print(f"\nUpdate simulator/config/default.yml with:")
    print(f"  endpoint: {endpoint}")

    print("\nDone! Certificates are ready in simulator/certs/")


if __name__ == "__main__":
    main()
