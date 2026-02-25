package staking

import (
	"testing"

	"github.com/stretchr/testify/suite"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/mercuryd/tests/integration"
	"github.com/huyCuong73/mercury/tests/integration/precompiles/staking"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestStakingPrecompileTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.StakingPrecompileApp](integration.CreateEvmd, "evm.StakingPrecompileApp")
	s := staking.NewPrecompileTestSuite(create)
	suite.Run(t, s)
}

func TestStakingPrecompileIntegrationTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.StakingPrecompileApp](integration.CreateEvmd, "evm.StakingPrecompileApp")
	staking.TestPrecompileIntegrationTestSuite(t, create)
}
