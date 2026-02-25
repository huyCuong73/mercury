package slashing

import (
	"testing"

	"github.com/stretchr/testify/suite"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/mercuryd/tests/integration"
	"github.com/huyCuong73/mercury/tests/integration/precompiles/slashing"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestSlashingPrecompileTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.SlashingPrecompileApp](integration.CreateEvmd, "evm.SlashingPrecompileApp")
	s := slashing.NewPrecompileTestSuite(create)
	suite.Run(t, s)
}

func TestStakingPrecompileIntegrationTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.SlashingPrecompileApp](integration.CreateEvmd, "evm.SlashingPrecompileApp")
	slashing.TestPrecompileIntegrationTestSuite(t, create)
}
