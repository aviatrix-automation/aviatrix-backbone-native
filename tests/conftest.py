"""Shared test fixtures for terraform-based tests."""

import json
import os
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Generator
from urllib.parse import urljoin

import hcl2
import paramiko
import pytest
import requests

# -----------------------------------------------------------------------------
# Terraform Exceptions
# -----------------------------------------------------------------------------


class TerraformError(Exception):
    """Base exception for Terraform errors."""

    def __init__(self, message: str, returncode: int, cmd: list[str]) -> None:
        super().__init__(message)
        self.returncode: int = returncode
        self.cmd: list[str] = cmd


class TerraformInitError(TerraformError):
    """Raised when terraform init fails."""


class TerraformApplyError(TerraformError):
    """Raised when terraform apply fails."""


class TerraformDestroyError(TerraformError):
    """Raised when terraform destroy fails."""


# -----------------------------------------------------------------------------
# Terraform Helper Functions
# -----------------------------------------------------------------------------


def terraform_init(tf_dir: Path, upgrade: bool = True, timeout: int = 300) -> None:
    """Run terraform init in specified directory.

    Args:
        tf_dir: Directory containing terraform files.
        upgrade: Whether to upgrade providers/modules.
        timeout: Command timeout in seconds.

    Raises:
        TerraformInitError: If init fails.
    """
    cmd = ["terraform", "init"]
    if upgrade:
        cmd.append("-upgrade")

    result = subprocess.run(
        cmd,
        cwd=tf_dir,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    if result.returncode != 0:
        raise TerraformInitError(f"terraform init failed: {result.stderr}", result.returncode, cmd)


def terraform_apply(tf_dir: Path, var_file: str, timeout: int = 1800) -> None:
    """Run terraform apply in specified directory.

    Args:
        tf_dir: Directory containing terraform files.
        var_file: Path to terraform var file.
        timeout: Command timeout in seconds (default 30 minutes).

    Raises:
        TerraformApplyError: If apply fails.
    """
    cmd = ["terraform", "apply", "-auto-approve", "-var-file", var_file]

    result = subprocess.run(
        cmd,
        cwd=tf_dir,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    if result.returncode != 0:
        raise TerraformApplyError(f"terraform apply failed: {result.stderr}", result.returncode, cmd)


def terraform_destroy(tf_dir: Path, var_file: str, timeout: int = 1800) -> None:
    """Run terraform destroy in specified directory.

    Args:
        tf_dir: Directory containing terraform files.
        var_file: Path to terraform var file.
        timeout: Command timeout in seconds (default 30 minutes).

    Raises:
        TerraformDestroyError: If destroy fails.
    """
    cmd = ["terraform", "destroy", "-auto-approve", "-var-file", var_file]

    result = subprocess.run(
        cmd,
        cwd=tf_dir,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    if result.returncode != 0:
        raise TerraformDestroyError(f"terraform destroy failed: {result.stderr}", result.returncode, cmd)


def terraform_output(tf_dir: Path) -> dict:
    """Load terraform outputs from state file.

    Args:
        tf_dir: Directory containing terraform state.

    Returns:
        Dictionary of outputs with format {"key": {"value": value}}.
    """
    state_file = tf_dir / "terraform.tfstate"
    if not state_file.exists():
        return {}

    with open(state_file) as f:
        state = json.load(f)

    outputs = {}
    for key, value in state.get("outputs", {}).items():
        outputs[key] = {"value": value.get("value")}
    return outputs


# -----------------------------------------------------------------------------
# Terraform Fixtures
# -----------------------------------------------------------------------------


@dataclass
class ProviderCred:
    aws_region: str
    aws_access_key: str
    aws_secret_key: str
    aviatrix_controller_ip: str
    aviatrix_controller_username: str
    aviatrix_controller_password: str
    aviatrix_aws_access_account: str


def _parse_provider_creds(creds_path: Path) -> ProviderCred:
    with open(creds_path) as f:
        data = hcl2.load(f)
    return ProviderCred(**data)


@pytest.fixture(scope="session")
def var_file() -> str:
    """Get the terraform var file path from AVX_TFVARS environment variable."""
    tf_var_file = os.environ.get("AVX_TFVARS")
    if not tf_var_file:
        pytest.skip("AVX_TFVARS environment variable not set")
    if not Path(tf_var_file).exists():
        pytest.skip(f"Var file not found: {tf_var_file}")
    return tf_var_file


@pytest.fixture(scope="module")
def change_test_dir(request: pytest.FixtureRequest) -> Generator[None, None, None]:
    """Change to test file directory for terraform operations."""
    original_dir = os.getcwd()
    os.chdir(request.fspath.dirname)
    yield
    os.chdir(original_dir)


@pytest.fixture(scope="module")
def tf(change_test_dir: None, var_file: str) -> Generator[dict, None, None]:  # noqa: ARG001
    """Terraform fixture: init, apply, yield outputs, destroy.

    Uses the current working directory (set by change_test_dir fixture).
    """
    tf_dir = Path.cwd()
    tf_error: TerraformError | None = None

    try:
        terraform_init(tf_dir)
        terraform_apply(tf_dir, var_file)
        outputs = terraform_output(tf_dir)
        yield {"outputs": outputs}

    except TerraformError as e:
        tf_error = e
        yield {"outputs": {}}

    finally:
        if not os.environ.get("AVX_NODESTROY"):
            try:
                terraform_destroy(tf_dir, var_file)
            except TerraformDestroyError as e:
                if tf_error is None:
                    tf_error = e

        if tf_error:
            raise tf_error


# -----------------------------------------------------------------------------
# VM Class for SSH and Ping Operations
# -----------------------------------------------------------------------------


class VM:
    """Represents a cloud VM with SSH and ping capabilities.

    Usage:
        # Create a bastion (public VM)
        bastion = VM("aws-bastion", private_ip="10.0.1.5", public_ip="54.1.2.3",
                     ssh_key_path="/path/to/key.pem")

        # Create a private VM that uses the bastion
        private_vm = VM("aws-private", private_ip="10.0.2.10", bastion=bastion,
                        ssh_key_path="/path/to/key.pem")

        # Ping from private VM to another IP
        success, output = private_vm.ping("10.20.2.15")
    """

    def __init__(
        self,
        name: str,
        private_ip: str,
        ssh_key_path: str,
        public_ip: str | None = None,
        bastion: "VM | None" = None,
        username: str = "ubuntu",
    ) -> None:
        """Initialize a VM instance.

        Args:
            name: Human-readable name for the VM.
            private_ip: Private IP address of the VM.
            ssh_key_path: Path to the SSH private key file.
            public_ip: Public IP address (if VM has one).
            bastion: Bastion VM to use for SSH access (for private VMs).
            username: SSH username (default: ubuntu).
        """
        self.name = name
        self.private_ip = private_ip
        self.public_ip = public_ip
        self.bastion = bastion
        self.ssh_key_path = ssh_key_path
        self.username = username

    def __repr__(self) -> str:
        return f"VM({self.name}, private_ip={self.private_ip}, public_ip={self.public_ip})"

    def ping(
        self,
        target_ip: str,
        max_retries: int = 5,
        retry_delay: int = 10,
        timeout: int = 60,
        ping_count: int = 3,
    ) -> tuple[bool, str]:
        """Ping a target IP from this VM.

        If the VM has a public IP, SSH directly into it.
        If the VM has a bastion, SSH through the bastion first.

        Args:
            target_ip: IP address to ping.
            max_retries: Maximum retry attempts for eventual consistency.
            retry_delay: Delay between retries in seconds.
            timeout: SSH connection timeout in seconds.
            ping_count: Number of ICMP ping packets to send.

        Returns:
            Tuple of (success: bool, output: str).

        Raises:
            ValueError: If VM has no public IP and no bastion configured.
        """
        if self.public_ip:
            return self._ping_direct(target_ip, max_retries, retry_delay, timeout, ping_count)
        elif self.bastion:
            return self._ping_via_bastion(target_ip, max_retries, retry_delay, timeout, ping_count)
        else:
            raise ValueError(f"VM {self.name} has no public IP and no bastion configured")

    def _ping_direct(
        self,
        target_ip: str,
        max_retries: int,
        retry_delay: int,
        timeout: int,
        ping_count: int,
    ) -> tuple[bool, str]:
        """Ping target by SSH-ing directly into this VM (has public IP)."""
        last_output = ""
        pkey = paramiko.RSAKey.from_private_key_file(self.ssh_key_path)

        for attempt in range(max_retries):
            client = paramiko.SSHClient()
            client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

            try:
                client.connect(
                    hostname=self.public_ip,
                    username=self.username,
                    pkey=pkey,
                    timeout=timeout,
                    look_for_keys=False,
                    allow_agent=False,
                )

                ping_cmd = f"ping -c {ping_count} -W 5 {target_ip}"
                stdin, stdout, stderr = client.exec_command(ping_cmd, timeout=timeout)

                exit_status = stdout.channel.recv_exit_status()
                output = stdout.read().decode("utf-8")
                error = stderr.read().decode("utf-8")

                if exit_status == 0:
                    return True, output

                last_output = f"{output}\n{error}"

            except Exception as e:
                last_output = str(e)

            finally:
                client.close()

            if attempt < max_retries - 1:
                time.sleep(retry_delay)

        return False, f"Failed after {max_retries} attempts. Last output: {last_output}"

    def _ping_via_bastion(
        self,
        target_ip: str,
        max_retries: int,
        retry_delay: int,
        timeout: int,
        ping_count: int,
    ) -> tuple[bool, str]:
        """Ping target by SSH-ing through bastion, then to this VM."""
        if not self.bastion or not self.bastion.public_ip:
            raise ValueError("Bastion must have a public IP")

        last_output = ""
        pkey = paramiko.RSAKey.from_private_key_file(self.ssh_key_path)

        for attempt in range(max_retries):
            bastion_client = paramiko.SSHClient()
            bastion_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            private_client = paramiko.SSHClient()
            private_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

            try:
                # Connect to bastion
                bastion_client.connect(
                    hostname=self.bastion.public_ip,
                    username=self.username,
                    pkey=pkey,
                    timeout=timeout,
                    look_for_keys=False,
                    allow_agent=False,
                )

                # Create channel through bastion to this VM
                bastion_transport = bastion_client.get_transport()
                if bastion_transport is None:
                    last_output = "Failed to get transport from bastion"
                    continue

                dest_addr = (self.private_ip, 22)
                local_addr = (self.bastion.public_ip, 22)
                channel = bastion_transport.open_channel("direct-tcpip", dest_addr, local_addr)

                # Connect to this VM through the channel
                private_client.connect(
                    hostname=self.private_ip,
                    username=self.username,
                    pkey=pkey,
                    timeout=timeout,
                    look_for_keys=False,
                    allow_agent=False,
                    sock=channel,
                )

                # Execute ping
                ping_cmd = f"ping -c {ping_count} -W 5 {target_ip}"
                stdin, stdout, stderr = private_client.exec_command(ping_cmd, timeout=timeout)

                exit_status = stdout.channel.recv_exit_status()
                output = stdout.read().decode("utf-8")
                error = stderr.read().decode("utf-8")

                if exit_status == 0:
                    return True, output

                last_output = f"{output}\n{error}"

            except Exception as e:
                last_output = str(e)

            finally:
                private_client.close()
                bastion_client.close()

            if attempt < max_retries - 1:
                time.sleep(retry_delay)

        return False, f"Failed after {max_retries} attempts. Last output: {last_output}"


# -----------------------------------------------------------------------------
# Gatus Health Monitoring
# -----------------------------------------------------------------------------


class GatusHealthMonitor:
    """Gatus health monitoring client for checking endpoint status.

    Usage:
        # Create a Gatus monitor
        gatus = GatusHealthMonitor("http://54.1.2.3:8080")

        # Check if Gatus is healthy
        success, message = gatus.check_health()

        # Check with authentication
        gatus_auth = GatusHealthMonitor(
            "http://54.1.2.3:8080",
            username="admin",
            password="secret"
        )
        success, message = gatus_auth.check_health()
    """

    def __init__(
        self,
        base_url: str,
        username: str | None = None,
        password: str | None = None,
    ) -> None:
        """Initialize a GatusHealthMonitor instance.

        Args:
            base_url: Base URL of the Gatus instance (e.g., http://ip:8080).
            username: Username for basic auth (optional).
            password: Password for basic auth (optional).
        """
        self.base_url = base_url.rstrip("/")
        self.username = username
        self.password = password

    def __repr__(self) -> str:
        return f"GatusHealthMonitor({self.base_url})"

    def check_health(
        self,
        max_retries: int = 5,
        retry_delay: int = 10,
        timeout: int = 30,
    ) -> tuple[bool, str]:
        """Check if Gatus is healthy by hitting the /health endpoint.

        Args:
            max_retries: Maximum retry attempts.
            retry_delay: Delay between retries in seconds.
            timeout: Request timeout in seconds.

        Returns:
            Tuple of (success: bool, message: str).
        """
        health_url = urljoin(self.base_url + "/", "health")
        last_error = ""

        auth = None
        if self.username and self.password:
            auth = (self.username, self.password)

        for attempt in range(max_retries):
            try:
                response = requests.get(
                    health_url,
                    auth=auth,
                    timeout=timeout,
                    verify=False,  # Skip SSL verification for test VMs
                )

                if response.status_code == 200:
                    return True, f"Gatus healthy: {response.text}"

                last_error = f"HTTP {response.status_code}: {response.text}"

            except requests.exceptions.RequestException as e:
                last_error = str(e)

            if attempt < max_retries - 1:
                time.sleep(retry_delay)

        return False, f"Failed after {max_retries} attempts. Last error: {last_error}"

    def get_status(
        self,
        timeout: int = 30,
    ) -> tuple[bool, dict | str]:
        """Get Gatus status from the /api/v1/endpoints/statuses endpoint.

        Args:
            timeout: Request timeout in seconds.

        Returns:
            Tuple of (success: bool, data: dict or error message: str).
        """
        status_url = urljoin(self.base_url + "/", "api/v1/endpoints/statuses")

        auth = None
        if self.username and self.password:
            auth = (self.username, self.password)

        try:
            response = requests.get(
                status_url,
                auth=auth,
                timeout=timeout,
                verify=False,
            )

            if response.status_code == 200:
                return True, response.json()

            return False, f"HTTP {response.status_code}: {response.text}"

        except requests.exceptions.RequestException as e:
            return False, str(e)
