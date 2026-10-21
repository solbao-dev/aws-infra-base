# AWS 리소스 정리 체크리스트

- **정리일:** 2026-10-22
- **리전:** 서울 `ap-northeast-2`
- **IAM 사용자:** `b3-1-lab`
- **프로젝트 태그:** `Project=b3-1`

> **주요 AWS 자원 정리 완료**
>
> 주요 AWS 자원·로컬 개인키 정리와 Billing 사용자 확인을 완료했습니다.

## 정리 현황

| 체크 | 정리 대상 | 확인 결과 | 상세 기록 |
| --- | --- | --- | --- |
| ✅ | EC2 | `terminated` 확인 | 1단계 |
| ✅ | EBS·ENI | 잔여 없음 `[]` | 2단계 |
| ✅ | Elastic IP | 서울 리전 할당 0개 | 3단계 |
| ✅ | Security Group | 삭제 후 조회 `[]` | 4단계 |
| ✅ | Route Table | 연결 해제·삭제, 기본 테이블도 잔여 없음 | 5단계 |
| ✅ | Public Subnet | 삭제 후 조회 `[]` | 6단계 |
| ✅ | Internet Gateway | 분리·삭제 후 조회 `[]` | 7단계 |
| ✅ | VPC·기본 Network ACL | 삭제 후 조회 `[]` | 8단계 |
| ✅ | AWS Key Pair | 삭제 후 조회 `[]` | 9단계 |
| ✅ | 추가 자원 | 실습 VPC NAT 0개·실습 태그 Snapshot 0개 | 10단계 |
| ✅ | 로컬 개인키 | 사용자 삭제 후 `Test-Path` → `False` | 11단계 |
| ✅ | Billing | 사용자 확인: 확인한 화면에 내역 없음 | 12단계 |

## 정리 순서와 의존 관계

**연결된 자원은 연결을 먼저 풀고, 다른 자원이 사용하는 자원은 나중에 삭제합니다.** 컴퓨터를 치울 때 실행 중인 작업을 끝내고, 연결된 선을 뺀 뒤 책상을 정리하는 것과 비슷합니다. 이런 연결 관계를 **의존 관계(Dependency)**라고 합니다.

이번 구성에서 EC2는 Subnet 안에서 실행되고, ENI(네트워크 인터페이스)를 통해 SG를 사용합니다. Subnet은 Route Table과 연결되어 있고, IGW는 VPC에 붙어 있습니다. 그래서 바깥 그릇인 VPC부터 지우려 하면, 안에 남아 있는 자원 때문에 삭제가 거부될 수 있습니다.

```text
증빙 보관
  → EC2 종료
  → 자동 정리된 EBS·ENI와 EIP 잔여 확인
  → SG 삭제
  → Route Table의 Subnet 연결 해제·테이블 삭제
  → Subnet 삭제
  → IGW를 VPC에서 분리·삭제
  → VPC 삭제
  → AWS Key Pair·로컬 개인키 정리
  → 잔여 자원·비용 확인
```

| 순서 | 쉽게 말하면 | 기술적인 이유 |
| --- | --- | --- |
| 1. 증빙 보관 | 치우기 전에 완성된 모습을 남깁니다. | EC2를 종료하면 웹 접속과 서버 로그 수집을 계속할 수 없으므로 결과를 먼저 저장합니다. |
| 2. EC2 종료 | 먼저 컴퓨터의 사용을 끝냅니다. | EC2가 사용하던 ENI가 정리되어 SG·Subnet 삭제를 진행할 수 있습니다. 루트 EBS도 자동 삭제 설정에 따라 제거되지만 실제 삭제 여부는 따로 확인합니다. |
| 3. SG·Route Table·Subnet 정리 | 사용이 끝난 출입 규칙과 연결을 정리합니다. | ENI가 사용하는 SG는 삭제할 수 없습니다. 이번에는 명시적 라우트 연결을 해제하고 사용자 지정 Route Table과 Subnet을 삭제했습니다. |
| 4. IGW 분리·삭제 | 외부로 이어지는 출입구를 떼어냅니다. | IGW는 VPC에서 `Detach`한 뒤 삭제합니다. VPC를 삭제하기 전에 부착된 IGW를 정리합니다. |
| 5. VPC 삭제 | 안이 비워진 큰 공간을 정리합니다. | Subnet 등 의존 자원을 제거한 후 VPC를 삭제합니다. 기본 Route Table·Network ACL·기본 SG는 VPC 삭제와 함께 제거됩니다. |
| 6. 키·잔여 자원·비용 확인 | 열쇠를 정리하고 남겨둔 물건이 없는지 확인합니다. | AWS Key Pair와 로컬 개인키는 별개입니다. EBS·EIP 같은 잔여 자원과 Billing도 따로 확인합니다. |

**이 순서만 가능한 것은 아닙니다.** SG 삭제와 Route Table 정리처럼 선후 관계가 없는 작업은 순서를 바꿀 수 있습니다. 핵심은 **사용 중인 연결을 먼저 해제하고, 의존하는 자원을 정리한 다음 VPC를 삭제하는 것**입니다. EIP는 이번에 없었지만, 있었다면 연결을 해제하고 `Release`했어야 합니다.

---

## 단계별 정리 및 검증 기록

아래는 **실제 작업 순서별 기록**이다. 명령은 실행 파일 경로와 공통 옵션을 줄여 표기했고, 조회 출력은 필요한 값만 발췌했다. 전체 터미널 원본은 아니다. 이번 문서 편집에서 AWS 명령을 다시 실행하지 않았다.

- 모든 AWS 명령: `--profile b3-1-lab --region ap-northeast-2 --no-cli-pager` 적용
- 아래 코드의 `@labOptions`는 다음 공통 옵션을 뜻한다.
- 삭제 명령은 이미 실행한 기록이므로 다시 실행할 필요가 없다.
- 삭제 후 최종 조회 완료: **2026-10-22 05:42:50 KST**. 각 자원의 정확한 삭제 시각은 아니다.

```powershell
$labOptions = @(
  '--profile', 'b3-1-lab',
  '--region', 'ap-northeast-2',
  '--no-cli-pager'
)
```

### 1. EC2 종료

**처리:** 콘솔에서 실습 인스턴스를 Terminate한 뒤 CLI로 상태를 확인했다.

```powershell
aws ec2 describe-instances `
  --instance-ids i-08bb6f3f6d2fb2d0a `
  --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name}' @labOptions
```

**실제 결과 발췌**

```text
{"ID":"i-08bb6f3f6d2fb2d0a","State":"terminated"}
```

**판단:** 종료 완료. 목록에서 사라지는 대신 `terminated` 상태로 확인한다.

### 2. EBS·ENI 자동 정리 확인

**처리:** EC2 종료 후 루트 볼륨과 실습 VPC의 네트워크 인터페이스를 조회했다. 이미 없어 별도 삭제 명령은 실행하지 않았다.

```powershell
aws ec2 describe-volumes `
  --filters Name=volume-id,Values=vol-0b0da79b429d525f5 `
  --query 'Volumes' @labOptions
aws ec2 describe-network-interfaces `
  --filters Name=vpc-id,Values=vpc-00b244a1bfda6e308 `
  --query 'NetworkInterfaces' @labOptions
```

**실제 결과 발췌**

```text
EBS: []
ENI: []
```

**판단:** 루트 EBS와 ENI 잔여 없음. `DeleteOnTermination=true` 설정뿐 아니라 조회 결과로 삭제를 확인했다.

### 3. Elastic IP 확인

**처리:** 서울 리전의 EIP 할당을 조회했다. 이번 실습은 자동 할당 퍼블릭 IPv4를 사용해 Release할 EIP가 없었다.

```powershell
aws ec2 describe-addresses --query 'length(Addresses)' @labOptions
```

**실제 결과 발췌**

```text
0
```

**판단:** 서울 리전 EIP 할당 없음. `release-address`는 실행하지 않았다.

### 4. Security Group 삭제

**처리:** EC2 ENI가 없음을 확인한 뒤 실습 SG를 삭제하고 같은 ID로 재조회했다.

```powershell
aws ec2 delete-security-group --group-id sg-02ee598fcadaa804b @labOptions
aws ec2 describe-security-groups `
  --filters Name=group-id,Values=sg-02ee598fcadaa804b `
  --query 'SecurityGroups' @labOptions
```

**실제 결과 발췌**

```text
삭제 응답: Return=true, GroupId=sg-02ee598fcadaa804b
재조회: []
```

**판단:** 실습 SG 삭제 완료.

### 5. Route Table 연결 해제·삭제

**처리:** Subnet의 명시적 연결을 해제한 뒤 사용자 지정 Route Table을 삭제했다. VPC 삭제 후 기본 테이블까지 함께 재확인했다.

```powershell
aws ec2 disassociate-route-table --association-id rtbassoc-037d17925ae3963bf @labOptions
aws ec2 delete-route-table --route-table-id rtb-00beb2d61a873e3e3 @labOptions
aws ec2 describe-route-tables `
  --filters Name=vpc-id,Values=vpc-00b244a1bfda6e308 `
  --query 'RouteTables' @labOptions
```

**실제 결과 발췌**

```text
연결 해제: 종료 코드 0
삭제: 종료 코드 0
VPC 삭제 후 재조회: []
```

**판단:** 사용자 지정 테이블 삭제 완료. 기본 테이블 `rtb-05955796be40ec98e`도 VPC 삭제 후 남지 않았다.

### 6. Public Subnet 삭제

**처리:** 라우트 연결 해제 후 실습 Subnet을 삭제하고 재조회했다.

```powershell
aws ec2 delete-subnet --subnet-id subnet-06f6fad18a908250d @labOptions
aws ec2 describe-subnets `
  --filters Name=subnet-id,Values=subnet-06f6fad18a908250d `
  --query 'Subnets' @labOptions
```

**실제 결과 발췌**

```text
삭제: 종료 코드 0
재조회: []
```

**판단:** 실습 Subnet 삭제 완료.

### 7. Internet Gateway 분리·삭제

**처리:** IGW를 실습 VPC에서 Detach한 뒤 삭제하고 재조회했다.

```powershell
aws ec2 detach-internet-gateway `
  --internet-gateway-id igw-060d4627edb6ef438 `
  --vpc-id vpc-00b244a1bfda6e308 @labOptions
aws ec2 delete-internet-gateway --internet-gateway-id igw-060d4627edb6ef438 @labOptions
aws ec2 describe-internet-gateways `
  --filters Name=internet-gateway-id,Values=igw-060d4627edb6ef438 `
  --query 'InternetGateways' @labOptions
```

**실제 결과 발췌**

```text
분리: 종료 코드 0
삭제: 종료 코드 0
재조회: []
```

**판단:** IGW 분리 및 삭제 완료.

### 8. VPC·기본 자원 삭제 확인

**처리:** 연결 자원 정리 후 VPC를 삭제했다. 기본 Route Table과 Network ACL은 VPC 삭제에 따라 제거됐는지 조회했다.

```powershell
aws ec2 delete-vpc --vpc-id vpc-00b244a1bfda6e308 @labOptions
aws ec2 describe-vpcs --filters Name=vpc-id,Values=vpc-00b244a1bfda6e308 --query 'Vpcs' @labOptions
aws ec2 describe-network-acls `
  --filters Name=vpc-id,Values=vpc-00b244a1bfda6e308 `
  --query 'NetworkAcls' @labOptions
```

**실제 결과 발췌**

```text
VPC 삭제: 종료 코드 0
VPC 재조회: []
Network ACL 재조회: []
```

**판단:** 실습 VPC와 기본 ACL 제거 확인. Route Table 확인은 5단계에 기록했다.

### 9. AWS Key Pair 삭제

**처리:** 실습 키페어를 AWS에서 삭제하고 이름으로 재조회했다.

```powershell
aws ec2 delete-key-pair --key-name b3-1-key @labOptions
aws ec2 describe-key-pairs --filters Name=key-name,Values=b3-1-key --query 'KeyPairs' @labOptions
```

**실제 결과 발췌**

```text
삭제 응답: Return=true
재조회: []
```

**판단:** AWS 키페어 삭제 완료. 개인 PC의 `.pem` 파일은 별도 정리가 필요하다.

### 10. 추가 자원 확인

**처리:** 실습 VPC의 NAT Gateway와 본인 소유 중 실습 태그가 있는 스냅샷을 조회했다.

```powershell
aws ec2 describe-nat-gateways `
  --filter Name=vpc-id,Values=vpc-00b244a1bfda6e308 `
  --query 'length(NatGateways)' @labOptions
aws ec2 describe-snapshots `
  --owner-ids self `
  --filters Name=tag:Project,Values=b3-1 `
  --query 'length(Snapshots)' @labOptions
```

**실제 결과 발췌**

```text
NAT Gateway: 0
```

**판단:** 해당 범위의 잔여 없음. 태그 없는 스냅샷 전체를 검사한 결과는 아니다. 공유 AMI 스냅샷은 삭제하지 않았다. ELB/ALB·RDS는 구축 기록상 미생성이며 별도 서비스 API 조회는 수행하지 않았다.

### 11. 로컬 개인키 정리 — 완료

**처리:** 파일 접근 권한 때문에 최초 삭제가 거부됐다. 이후 사용자가 로컬 PowerShell에서 해당 키 파일에만 수정 권한을 부여한 뒤 삭제했다.

```powershell
$labKey = "$env:USERPROFILE\Desktop\b3-1-key.pem"
$labUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

icacls.exe "$labKey" /grant:r "${labUser}:(M)"
Remove-Item -LiteralPath $labKey -Force
Test-Path -LiteralPath $labKey
```

**사용자 제공 실행 결과 발췌**

```text
1 파일을 처리했으며 0 파일은 처리하지 못했습니다.
False
```

**판단:** 지정한 로컬 개인키 경로에 파일이 없음을 확인했다. 사용자가 제공한 실행 결과를 근거로 완료 처리했으며, 다른 위치의 복사본이나 백업 전체를 검사한 결과는 아니다.

### 12. Billing 최종 확인 — 완료

**확인 범위:** 앞서 안내한 관리자 콘솔의 Billing → Bills → 2026년 10월 내역.

**사용자 확인 결과:** “확인완료 없음”. 사용자가 확인한 Billing 화면에 내역이 없었다고 보고했다.

**판단:** 사용자 확인을 근거로 완료 처리했다. 에이전트가 Billing API나 화면을 직접 조회한 결과는 아니며 별도 스크린샷은 보관하지 않았다. 조회 당시 화면의 표시 결과로, 향후 지연 반영될 사용 내역이나 청구 금액까지 0원으로 확정한 것은 아니다.

---

## 최종 체크리스트

- [x] 외부 접속 사진·설계도·트러블슈팅·서버 로그 보관
- [x] EC2 종료 상태 확인
- [x] EBS·ENI 삭제 확인
- [x] EIP 할당 없음 확인
- [x] SG·Route Table·Subnet 삭제 확인
- [x] IGW 분리·삭제 및 VPC 삭제 확인
- [x] 기본 Route Table·Network ACL 제거 확인
- [x] AWS Key Pair 삭제 확인
- [x] 실습 VPC NAT Gateway·실습 태그 Snapshot 없음 확인
- [x] 로컬 개인키 삭제 확인
- [x] Billing 최종 확인 — 사용자 확인: 내역 없음

조회의 빈 배열 `[]` 또는 개수 0은 **성공한 해당 조회 범위에서 자원이 없다는 뜻**이다. 권한·네트워크 오류를 자원 없음으로 처리하지 않았다. 이 기록은 실습 자원 정리 근거이며 계정 전체의 모든 서비스나 모든 비용이 없다는 의미는 아니다.
