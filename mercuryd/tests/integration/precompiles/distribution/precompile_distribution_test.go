package distribution

import (
	"testing"

	"github.com/stretchr/testify/suite"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/mercuryd/tests/integration"
	"github.com/huyCuong73/mercury/tests/integration/precompiles/distribution"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestDistributionPrecompileTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.DistributionPrecompileApp](integration.CreateEvmd, "evm.DistributionPrecompileApp")
	s := distribution.NewPrecompileTestSuite(create)
	suite.Run(t, s)
}

func TestDistributionPrecompileIntegrationTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.DistributionPrecompileApp](integration.CreateEvmd, "evm.DistributionPrecompileApp")
	distribution.TestPrecompileIntegrationTestSuite(t, create)
}
