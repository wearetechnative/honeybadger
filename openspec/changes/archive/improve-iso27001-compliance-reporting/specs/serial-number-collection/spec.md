## ADDED Requirements

### Requirement: System SHALL collect device serial number
The audit process SHALL retrieve the device serial number using `dmidecode -s system-serial-number` during the hardware information collection phase.

#### Scenario: Serial number successfully retrieved
- **WHEN** the audit runs with root/sudo privileges
- **THEN** the system SHALL execute `dmidecode -s system-serial-number`
- **AND** SHALL store the serial number in the asset inventory

#### Scenario: Serial number unavailable
- **WHEN** dmidecode is not installed or returns empty value
- **THEN** the system SHALL record "Not available" or "Unknown" as the serial number
- **AND** SHALL NOT fail the audit

### Requirement: Serial number SHALL be displayed in asset inventory
The asset inventory report SHALL display the device serial number as a separate field from the model/description.

#### Scenario: Serial number shown separately from model
- **WHEN** asset inventory is generated
- **THEN** the report SHALL contain a "Serial Number" field with the actual serial number
- **AND** SHALL contain a separate "Model" field with the device model information

#### Scenario: Report format includes serial number
- **WHEN** viewing the asset-inventory.txt file
- **THEN** the serial number SHALL appear in the format: `Serial Number | <value>`
- **AND** the model SHALL appear in the format: `Model | <value>`

### Requirement: System SHALL handle virtual machines appropriately
The audit process SHALL handle cases where serial numbers are not meaningful (virtual machines, containers).

#### Scenario: Virtual machine serial number
- **WHEN** the system detects it is running in a VM
- **THEN** the serial number field SHALL still be populated with the VM's serial number or "VM: Not applicable"
- **AND** SHALL NOT treat this as an error condition
